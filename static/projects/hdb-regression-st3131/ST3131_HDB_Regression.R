# =============================================================================
# HDB Resale Price (July 2020)
# =============================================================================
library(car)
library(MASS)
library(corrplot)
set.seed(42)

# =============================================================================
# 1. LOAD & FEATURE ENGINEERING
# =============================================================================
df <- read.csv("hdb-resale-July-2020.csv", stringsAsFactors = FALSE)

# Remaining lease -> decimal years (67 years 3 months -> 67.25)
parse_lease <- function(x) {
  years  <- as.numeric(regmatches(x, regexpr("\\d+(?= year)",  x, perl = TRUE)))
  m      <- regexpr("\\d+(?= month)", x, perl = TRUE)
  months <- ifelse(m > 0, as.numeric(regmatches(x, m)), 0)
  years + months / 12
}
df$remaining_lease_dec <- parse_lease(df$remaining_lease)

# Storey midpoint (e.g. "04 TO 06" -> 5)
df$storey_mid <- sapply(df$storey_range, function(x)
  mean(as.numeric(regmatches(x, gregexpr("\\d+", x))[[1]])))

# Flat age at sale
df$flat_age <- 2020 - df$lease_commence_date

# Collapse MULTI-GENERATION (n=1) into EXECUTIVE to avoid near-singular dummy
df$flat_type[df$flat_type == "MULTI-GENERATION"] <- "EXECUTIVE"
df$flat_type <- factor(df$flat_type,
                       levels = c("1 ROOM","2 ROOM","3 ROOM","4 ROOM",
                                  "5 ROOM","EXECUTIVE"))
df$town <- factor(df$town)

# =============================================================================
# 2. EDA
# =============================================================================

# Mean and Median (handle NAs just in case --> checked on excel already)
mean_price <- mean(df$resale_price, na.rm = TRUE)
median_price <- median(df$resale_price, na.rm = TRUE)

# standard deviation and skewness for context
sd_price <- sd(df$resale_price, na.rm = TRUE)
skew_price <- sum((df$resale_price - mean_price)^3) / 
  (length(df$resale_price) * sd_price^3)
df$log_price <- log(df$resale_price)
skew_log <- sum((df$log_price - mean(df$log_price))^3) / 
  (length(df$log_price) * sd(df$log_price)^3)

# --- 2.1 Response variable ---
par(mfrow = c(1, 3))
hist(df$resale_price, breaks = 40, col = "steelblue",
     main = "Histogram: Resale Price", xlab = "Resale Price (SGD)")
hist(log(df$resale_price), breaks = 40, col = "darkorange",
     main = "Histogram: log(Resale Price)", xlab = "log(Price)")
qqnorm(df$resale_price, main = "Q-Q Plot: Resale Price")
qqline(df$resale_price, col = "red")
par(mfrow = c(1, 1))
# Observation: raw price is right-skewed while log(price) is approximately symmetric
# Just check log price along with raw price to see fit 

# --- 2.2 Continuous predictors vs resale price ---
par(mfrow = c(2, 3))
plot(df$floor_area_sqm, df$resale_price, pch = 20, cex = 0.5,
     xlab = "Floor Area (sqm)", ylab = "Price", main = "Price vs Floor Area")
abline(lm(resale_price ~ floor_area_sqm, data = df), col = "red")

plot(df$storey_mid, df$resale_price, pch = 20, cex = 0.5,
     xlab = "Storey Midpoint", ylab = "Price", main = "Price vs Storey")
abline(lm(resale_price ~ storey_mid, data = df), col = "red")

plot(df$remaining_lease_dec, df$resale_price, pch = 20, cex = 0.5,
     xlab = "Remaining Lease (years)", ylab = "Price", main = "Price vs Remaining Lease")
abline(lm(resale_price ~ remaining_lease_dec, data = df), col = "red")

plot(df$flat_age, df$resale_price, pch = 20, cex = 0.5,
     xlab = "Flat Age (years)", ylab = "Price", main = "Price vs Flat Age")
abline(lm(resale_price ~ flat_age, data = df), col = "red")

plot(df$lease_commence_date, df$resale_price, pch = 20, cex = 0.5,
     xlab = "Lease Commence Year", ylab = "Price", main = "Price vs Lease Commence")
abline(lm(resale_price ~ lease_commence_date, data = df), col = "red")
par(mfrow = c(1, 1))
# Observation: flat_age and lease_commence_date are mirror images of each other
# and are both linear functions of remaining_lease_dec (sale date fixed at July 2020)
# -> keep only remaining_lease_dec; drop the other two from the model

# --- 2.3 Categorical predictors ---
par(mfrow = c(1, 2))
boxplot(resale_price ~ town, data = df, col = "lightblue",
        main = "Price by Town", xlab = "", ylab = "Price (SGD)",
        las = 2, cex.axis = 0.55)
boxplot(resale_price ~ flat_type, data = df, col = "lightgreen",
        main = "Price by Flat Type", xlab = "", ylab = "Price (SGD)",
        las = 2, cex.axis = 0.7)
par(mfrow = c(1, 1))
# Observation: substantial price variation across towns (Bukit Timah >> Woodlands)
# Cannot categorise them into regions as they will lose information about within region 
# variations in prices. 
# and clear monotonic increase from 1 ROOM to EXECUTIVE --> both are strong predictors

# =============================================================================
# 3. MULTICOLLINEARITY DIAGNOSTICS
# =============================================================================

# Known collinear pairs :
#   - street_name nested within town --> use town only
#   - flat_age and lease_commence_date are linear functions of remaining_lease_dec
#     given a fixed sale date -> keep remaining_lease_dec only
#   - flat_type and floor_area_sqm are correlated by construction (larger type = larger area)
#     a. both retained in M0. VIF will quantify residual collinearity

# Numerical check on the three retained continuous predictors
num_vars <- as.matrix(df[, c("floor_area_sqm", "storey_mid", "remaining_lease_dec", 
                             "flat_age", "lease_commence_date")])
cor_mat <- cor(num_vars)

cat("Correlation matrix (continuous predictors):\n")
print(round(cor_mat, 4))

corrplot(cor_mat, method = "color", addCoef.col = "black",
         tl.cex = 0.9, number.cex = 0.8,
         title = "Correlation Matrix: Continuous Predictors",
         mar = c(0, 0, 2, 0))

num_vars2 <- as.matrix(df[, c("floor_area_sqm", "storey_mid", "remaining_lease_dec")])
cor_mat2 <- cor(num_vars2)

# Condition number κ = λ_max / λ_min (computed from correlation matrix)
eig   <- eigen(cor_mat2)
kappa <- max(eig$values) / min(eig$values)
cat(sprintf("\nEigenvalues: %s\n", paste(round(eig$values, 4), collapse = ", ")))
cat(sprintf("Condition number κ = %.4f", kappa))
cat(ifelse(kappa < 100, "No multicollinearity concern\n",
           ifelse(kappa < 1000, "Moderate\n", " -> Severe\n")))

# Pairs plot
pairs(num_vars, pch = 20, cex = 0.3, col = "steelblue",
      main = "Pairs Plot: Continuous Predictors")

# =============================================================================
# 4. INITIAL MODEL M0 
# =============================================================================
# Regressors: floor_area_sqm, storey_mid, remaining_lease_dec (quantitative)
#             town, flat_type (categorical)
M0 <- lm(resale_price ~ floor_area_sqm + storey_mid +
           remaining_lease_dec + town + flat_type,
         data = df)

summary(M0)
anova(M0)
cat("\nVIF (M0):\n"); print(vif(M0))
cat(sprintf("\nM0  Adj-R² = %.4f  |  AIC = %.2f\n",
            summary(M0)$adj.r.squared, AIC(M0)))

# =============================================================================
# 5. BOX-COX TRANSFORMATION
# =============================================================================
df_bc <- na.omit(df[, c("resale_price", "floor_area_sqm", "storey_mid", 
                        "remaining_lease_dec", "town", "flat_type")])
bc <- boxcox(M0, data = df_bc, lambda = seq(-2, 2, 0.1), plotit = TRUE)
lambda_opt <- bc$x[which.max(bc$y)]
cat(sprintf("\nBox-Cox optimal λ = %.4f", lambda_opt))

# =============================================================================
# 6. LOG-TRANSFORMED INITIAL MODEL (M0_log)
# =============================================================================
M0_log <- lm(log(resale_price) ~ floor_area_sqm + storey_mid +
               remaining_lease_dec + town + flat_type,
             data = df)

# =============================================================================
# 6.1 BOX-COX λ = -0.5 MODEL (M0_bc) — Alternative Transformation
# =============================================================================
df$price_bc <- 1 / sqrt(df$resale_price)  # λ = -0.5: reciprocal square root
M0_bc <- lm(price_bc ~ floor_area_sqm + storey_mid +
              remaining_lease_dec + town + flat_type,
            data = df)

# =============================================================================
# 6.2 MODEL ADEQUACY CHECKING: Compare ALL THREE Transformations 
# =============================================================================
# Function to generate MAC plots for any model
mac_plots <- function(model, response_name, df, cont_vars) {
  SR <- rstandard(model)
  fitted <- fitted(model)
  mf <- model.frame(model)
  idx <- as.numeric(rownames(mf))
  
  par(mfrow = c(2, 3), mar = c(4, 4, 2, 1))
  
  # QQ Plot
  qqnorm(SR, main = paste("QQ Plot:", response_name), pch = 20, cex = 0.5)
  qqline(SR, col = "red", lwd = 2)
  
  # Residuals vs Fitted
  plot(fitted, SR, pch = 20, cex = 0.5, col = "steelblue",
       xlab = "Fitted Values", ylab = "Standardized Residuals",
       main = paste("SR vs Fitted:", response_name))
  abline(h = 0, col = "red", lwd = 2)
  abline(h = c(-2, 2), col = "orange", lty = 2)
  lines(lowess(fitted, SR), col = "blue", lwd = 1.5)
  
  # Residuals vs each continuous predictor
  for (v in cont_vars) {
    plot(df[[v]][idx], SR, pch = 20, cex = 0.5, col = "gray40",
         xlab = v, ylab = "Standardized Residuals",
         main = paste("SR vs", v))
    abline(h = 0, col = "red", lwd = 2)
    lines(lowess(df[[v]][idx], SR), col = "blue", lwd = 1.5)
  }
  par(mfrow = c(1, 1))
  
  # Formal tests
  sw <- shapiro.test(SR[sample(length(SR), min(length(SR), 5000))])
  dw <- durbinWatsonTest(model)
  
  cat(sprintf("\n%s:\n", response_name))
  cat(sprintf("  Shapiro-Wilk: W = %.4f, p = %.4f\n", sw$statistic, sw$p.value))
  cat(sprintf("  Durbin-Watson: D = %.4f, p = %.4f\n", dw$dw, dw$p))
  cat(sprintf("  Adj-R² = %.4f | MS_Res = %.4f | AIC = %.2f | BIC = %.2f\n",
              summary(model)$adj.r.squared, sigma(model)^2, AIC(model), BIC(model)))
  
  invisible(list(SR = SR, fitted = fitted, sw = sw, dw = dw))
}

# Continuous predictors for residual plots
cont_vars <- c("floor_area_sqm", "storey_mid", "remaining_lease_dec")

# Run MAC on all three models
cat("\n=== MODEL ADEQUACY CHECKING: Comparing Transformations ===\n")
mac_raw  <- mac_plots(M0,      "Raw_Price",      df, cont_vars)
mac_log  <- mac_plots(M0_log,  "Log_Price",      df, cont_vars)
mac_bc   <- mac_plots(M0_bc,   "BC_lambda_-0.5", df, cont_vars)

# =============================================================================
# 6.3 Transformation Selection Decision 
# =============================================================================
# Decision table with all parameters to make a decision
decision_tbl <- data.frame(
  Model = c("Raw_Price", "Log_Price", "BC_lambda_-0.5"),
  Adj_R2 = c(summary(M0)$adj.r.squared, 
             summary(M0_log)$adj.r.squared, 
             summary(M0_bc)$adj.r.squared),
  MS_Res = c(sigma(M0)^2, sigma(M0_log)^2, sigma(M0_bc)^2),
  Interpretability = c("Original units", "% change via exp(β)-1", "Difficult")
)
print(decision_tbl)

# =============================================================================
# 7. SELECT FINAL TRANSFORMATION & PROCEED WITH STEPWISE SELECTION
# =============================================================================
# Based on your MAC plots and the table above, choosing log transformation 

# We proceed with log-transformed model (as justified by EDA + MAC)
MN <- stepAIC(M0_log, direction = "both", trace = TRUE)

summary(MN)
anova(MN)
cat("\nVIF (MN):\n"); print(vif(MN))
cat(sprintf("\nMN  Adj-R² = %.4f  |  AIC = %.2f\n",
            summary(MN)$adj.r.squared, AIC(MN)))

# =============================================================================
# 8. MODEL ADEQUACY CHECKING — FINAL MODEL MN 
# =============================================================================
SR_MN     <- rstandard(MN)
fitted_MN <- fitted(MN)
mf_MN     <- model.frame(MN)
cont_MN   <- names(mf_MN)[-1][sapply(mf_MN[-1], is.numeric)]
idx       <- as.numeric(rownames(mf_MN))

n_plots <- length(cont_MN) + 2
par(mfrow = c(2, ceiling(n_plots / 2)))

# QQ plot
qqnorm(SR_MN, main = "Q-Q Plot: Standardized Residuals", pch = 20, cex = 0.5)
qqline(SR_MN, col = "red", lwd = 2)

# Residuals vs fitted
plot(fitted_MN, SR_MN, pch = 20, cex = 0.5,
     xlab = "Fitted log(Price)", ylab = "Standardized Residuals",
     main = "Residuals vs Fitted")
abline(h = 0,        col = "red",    lwd = 2)
abline(h = c(-2, 2), col = "orange", lty = 2)
lines(lowess(fitted_MN, SR_MN), col = "blue", lwd = 1.5)

# Residuals vs each continuous predictor
for (v in cont_MN) {
  plot(df[[v]][idx], SR_MN, pch = 20, cex = 0.5,
       xlab = v, ylab = "Standardized Residuals",
       main = paste("Residuals vs", v))
  abline(h = 0,        col = "red",    lwd = 2)
  abline(h = c(-2, 2), col = "orange", lty = 2)
  lines(lowess(df[[v]][idx], SR_MN), col = "blue", lwd = 1.5)
}
par(mfrow = c(1, 1))

# Formal tests
sw <- shapiro.test(SR_MN[sample(length(SR_MN), min(length(SR_MN), 5000))])
dw <- durbinWatsonTest(MN)
cat("\n--- MAC Formal Tests (Final Model MN) ---\n")
cat(sprintf("Shapiro-Wilk  W = %.4f,  p = %.4f\n", sw$statistic, sw$p.value))
cat(sprintf("Durbin-Watson D = %.4f,  p = %.4f\n", dw$dw, dw$p))

# =============================================================================
# 9. INFLUENTIAL POINTS  
# =============================================================================
cook     <- cooks.distance(MN)
hat_vals <- hatvalues(MN)
p_coef   <- length(coef(MN))
n_obs    <- nrow(mf_MN)
cut_lev  <- 2 * p_coef / n_obs

cat(sprintf("Influential (Cook's D > 1):        %d obs\n", sum(cook > 1)))
cat(sprintf("High-leverage (h > 2p/n = %.4f):  %d obs\n",
            cut_lev, sum(hat_vals > cut_lev)))
cat(sprintf("Outliers (|SR| > 3):               %d obs\n", sum(abs(SR_MN) > 3)))
cat(sprintf("Boxplot outliers (SR):             %d obs\n",
            length(boxplot(SR_MN, plot = FALSE)$out)))

plot(cook, type = "h", ylab = "Cook's Distance",
     xlab = "Observation Index", main = "Cook's Distance — Final Model MN")
abline(h = 1, col = "red", lty = 2)
# =============================================================================
# 10. MODEL INTERPRETATION
# =============================================================================
coef_MN <- coef(MN)

# 1. Continuous Predictors (per 1-unit increase)
cont_vars <- c("floor_area_sqm", "storey_mid", "remaining_lease_dec")
cat("\n--- Continuous Predictor Effects (per 1-unit increase) ---\n")
for (v in cont_vars) {
  if (v %in% names(coef_MN)) {
    b <- coef_MN[v]
    cat(sprintf("  %-25s β = %+.5f  ->  %+.3f%%\n", v, b, (exp(b) - 1) * 100))
  }
}

# 2. Flat Type Effects (vs 1 ROOM baseline)
flat_coefs <- coef_MN[grepl("^flat_type", names(coef_MN))]
if (length(flat_coefs) > 0) {
  cat("\n--- Flat Type Effects (vs 1 ROOM) ---\n")
  flat_order <- c("flat_type2 ROOM", "flat_type3 ROOM", "flat_type4 ROOM", 
                  "flat_type5 ROOM", "flat_typeEXECUTIVE")
  flat_coefs <- flat_coefs[intersect(flat_order, names(flat_coefs))]
  
  for (nm in names(flat_coefs)) {
    b <- flat_coefs[nm]
    cat(sprintf("  %-20s β = %+.5f  ->  %+.3f%%\n", nm, b, (exp(b) - 1) * 100))
  }
}

# 3. Town Effects (vs AMK baseline)
coef_MN <- coef(MN)
cat("\n--- Coefficient Interpretation (log-scale; % effect = (exp(β)-1)*100) ---\n")
for (nm in c("floor_area_sqm", "storey_mid", "remaining_lease_dec")) {
  if (nm %in% names(coef_MN)) {
    b <- coef_MN[nm]
    cat(sprintf("  %-25s β = %+.5f  ->  %+.3f%% per 1-unit increase\n",
                nm, b, (exp(b) - 1) * 100))
  }
}

# Top 5 town effects vs baseline (alphabetically first town)
town_coefs <- coef_MN[grepl("^town", names(coef_MN))]
if (length(town_coefs) > 0) {
  top5 <- sort(town_coefs, decreasing = TRUE)[1:min(5, length(town_coefs))]
  cat("\nTop 5 towns (highest premium vs baseline):\n")
  for (nm in names(top5))
    cat(sprintf("  %-30s %+.3f%%\n", nm, (exp(top5[nm]) - 1) * 100))
}
# Bottom 5 town effects vs baseline (largest discounts)
town_coefs <- coef_MN[grepl("^town", names(coef_MN))]
if (length(town_coefs) > 0) {
  bottom5 <- sort(town_coefs, decreasing = FALSE)[1:min(5, length(town_coefs))]
  cat("\nBottom 5 towns (largest discount vs baseline):\n")
  for (nm in names(bottom5))
    cat(sprintf("  %-30s %+.3f%%\n", nm, (exp(bottom5[nm]) - 1) * 100))
}

# =============================================================================
# 11. PREDICTIVE PERFORMANCE (IN-SAMPLE)
# =============================================================================
actual     <- df$resale_price[idx]
pred_price <- exp(predict(MN))
RMSE <- sqrt(mean((actual - pred_price)^2))
MAE  <- mean(abs(actual - pred_price))
MAPE <- mean(abs((actual - pred_price) / actual)) * 100
cat(sprintf("\nRMSE: SGD %.2f  |  MAE: SGD %.2f  |  MAPE: %.2f%%\n", RMSE, MAE, MAPE))

plot(actual, pred_price, pch = 20, cex = 0.4, col = "steelblue",
     xlab = "Actual Resale Price (SGD)", ylab = "Predicted Resale Price (SGD)",
     main = "Predicted vs Actual — Final Model MN")
abline(0, 1, col = "red", lwd = 2)- df$resale_price[idx]
pred_price <- exp(predict(MN))

# =============================================================================