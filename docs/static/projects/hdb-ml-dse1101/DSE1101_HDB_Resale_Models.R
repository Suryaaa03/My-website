# Clear all objects from the current R environment to start with a clean workspace.
rm(list=ls())

# Load required libraries for different parts of the analysis.
library(leaps)      # For performing stepwise feature selection using regsubsets.
library(rpart)      # For building regression tree models.
library(ROCR)       # For evaluating model performance using ROC curves and other metrics.
library(kknn)       # For k-nearest neighbors model implementation.
library(boot)       # For implementing cross-validation.

########## PRE-PROCESSING ######################################################
# Data Set was refined from 230 Predictors to 133 Predictors to reduce redundancy and collinearity.
# The predictors removed are stated below with the explanations.

# **The adjusted data file has been added to the zip file. It has been named HDB_data_2021_Final 
#   under the folder HDB_data_csv.**

# 1. Postal Code: Redundant due to overlap with the town variable.
# 2. Total Units Sold and Rental Units: Not directly impactful on price.
# 3. Max-Floor: The individual unit's floor has more relevance than the building's maximum floor.
# 4. MRT Lines and ADF within a Distance: Town-related amenities and proximity were more informative than these variables alone.

# Read the data set from a CSV file into an R data frame.
HDB_Data <- read.csv("HDB_data_2021_Final.csv", header = TRUE, stringsAsFactors = FALSE)

# Assign the read data set to a new variable 'df' for ease of use and to avoid modifying the original data.
df <- HDB_Data

# Calculate and print the mean resale price of HDB flats, rounded to 2 decimal places.
mean_resale_price <- round(mean(df$resale_price, na.rm = TRUE), 2)
cat("Mean of Resale Prices: ", mean_resale_price, "\n")  # Print the calculated mean resale price.

# Set the seed for reproducibility, ensuring the same data split each time the code is run.
set.seed(123456)

# Define the training set size (number of rows used for training).
ntrain <- 4000

# Randomly sample indices for the training data.
train_indices <- sample(1:nrow(df), ntrain)  # Selects 4000 random indices from the data frame.

# Create training and test sets based on sampled indices.
train_data <- df[train_indices, ]   # Training set based on sampled indices.
test_data <- df[-train_indices, ]   # Test set consisting of the remaining data.

# Open a window to display a plot (only needed for some operating systems).
windows()
# Plot a histogram of the original resale prices to visualize the distribution.
hist(df$resale_price, 
     main = "Histogram of Resale Price",  # Set title for the histogram.
     xlab = "Resale Price",               # Label for the x-axis.
     col = "lightblue",                   # Set bar color.
     border = "black")                    # Set border color for the bars.

# --- Visualize Resale Price Distribution ---
windows()
# Plot histogram of the resale price
boxplot(HDB_Data$resale_price, 
        main = "Horizontal Box Plot of Resale Prices",
        xlab = "Resale Price",
        col = "lightblue",
        horizontal = TRUE)
#Checking for anomalies (Extreme Values)

########## DATA TRANSFORMATION #################################################
# --- Log-Transformation of Resale Price ---
# Create a log-transformed version of the resale price to reduce skewness.
df$resale_price_log <- log(df$resale_price)
train_data$resale_price_log <- log(train_data$resale_price)
test_data$resale_price_log <- log(test_data$resale_price)

# Open a window to display a plot.
windows()
# Plot a histogram of the log-transformed resale prices to check the distribution after transformation.
hist(df$resale_price_log, 
     main = "Log-transformed Resale Price",  # Set title for the histogram.
     xlab = "Log(Resale Price)",             # Label for the x-axis.
     col = "lightblue",                      # Set bar color.
     border = "black")                       # Set border color for the bars.

########## LM MODEL ############################################################
# Set seed again for reproducibility before running model selection.
set.seed(123456)

# --- Step 1: Forward Selection using regsubsets ---
# Perform forward feature selection on the log-transformed resale price.
#I used forward selection for feature selection in the Linear Model. The forward selection process for the 
#linear model added predictors sequentially based on their significance, as determined by the adjusted R-squared. 
#This allowed the model to identify the most impactful predictors while avoiding multicollinearity and overfitting.
lm_fit <- regsubsets(resale_price_log ~ .-resale_price, data = df, method = "forward", nvmax = 133)
# Explanation: The `regsubsets` function selects the best combination of predictors using a forward selection approach.

# --- Step 2: Identify the Best Model Based on Adjusted R-squared ---
# Find the index of the model with the highest adjusted R-squared value.
best_model_index <- which.max(summary(lm_fit)$adjr2)
cat("Best model index based on adjusted R-squared:", best_model_index, "\n")  # Print the index of the best model.

# --- Step 3: Extract the Best Predictors ---
# Get the names of the predictors in the best model (excluding the intercept).
best_predictors <- names(coef(lm_fit, best_model_index))[-1]
cat("Best predictors: ", best_predictors, "\n")  # Print the selected predictors.

# --- Step 4: Fit Linear Model with the Best Predictors ---
# Create a formula using the best predictors for fitting a linear model.
best_formula <- as.formula(paste("resale_price_log ~", paste(best_predictors, collapse = " + ")))
lm_best_model <- lm(best_formula, data = train_data)  # Fit the linear model with the best predictors.
summary(lm_best_model)  # Display the summary of the fitted model to assess performance.

# --- Step 5: Calculate RMSE for Linear Model on Test Data ---
# Make predictions on the test set using the linear model.
predictions_lm_log <- predict(lm_best_model, newdata = test_data)
predictions_lm <- exp(predictions_lm_log)  # Convert log predictions back to the original scale.

# Calculate RMSE for model evaluation.
RMSE_lm <- sqrt(mean((test_data$resale_price - predictions_lm)^2))
cat("Linear Model (LM) - RMSE on original scale:", RMSE_lm, "\n")  # Print the RMSE.

# --- Step 6: Define Cross-validation Function for LM ---
# Define a function to perform cross-validation and calculate RMSE for each fold.
cv_lm <- function(data, indices) {
  train_data <- data[indices, ]  # Create training set for the current fold.
  test_data <- data[-indices, ]  # Create test set for the current fold.
  lm_model <- lm(best_formula, data = train_data)  # Fit linear model on training set.
  log_predictions <- predict(lm_model, newdata = test_data)  # Predict on the test set.
  predictions <- exp(log_predictions)  # Convert predictions back to the original scale.
  rmse_val <- sqrt(mean((test_data$resale_price - predictions)^2))  # Calculate RMSE.
  return(rmse_val)  # Return the RMSE for this fold.
}

########## EXPLANATION FOR WHY I CHOSE 10-FOLD CROSS VALIDATION ################

#Since the "rpart" package (commonly used for decision trees) employs 10-fold cross-validation 
#for pruning and model selection, it is consistent and logical to use the same cross-validation 
#method across all model evaluations. This uniformity ensures that performance metrics are 
#comparable and consistent, making it easier to interpret the results across different models. 

#It strikes a good balance between computational efficiency and variance in the model's 
#performance estimate. Using 10 folds results in a reliable estimate of the model's 
#generalization error with less computational cost compared to higher numbers like 
#leave-one-out cross-validation.

#In 10-fold cross-validation, the dataset is split into 10 equally-sized subsets, or "folds." 
#The model is trained on 9 of these folds and validated on the remaining one. This process is 
#repeated 10 times, each time using a different fold as the validation set while the other 9 
#folds are used for training. After completing all iterations, the performance metrics from each 
#fold are averaged to provide a final estimate of the model's predictive performance. 
#This method helps ensure the model's robustness by exposing it to varied training and validation sets.

# --- Step 7: Perform 10-fold Cross-validation for LM ---
# Run cross-validation with 10 iterations using the defined function.
cv_results_lm <- boot(data = df, statistic = cv_lm, R = 10)
RMSE_lm_cv <- mean(cv_results_lm$t)  # Calculate the mean RMSE across all folds.
cat("Mean RMSE from 10-fold CV for LM: ", RMSE_lm_cv, "\n")  # Print the mean RMSE.

# --- Step 8: Refit the Final Model Using the Full Training Data ---
# Fit the final linear model on the entire dataset using the best formula.
final_lm_model <- lm(best_formula, data = df)
summary(final_lm_model)
# --- Step 9: Get Predictions for Actual vs Predicted Plot ---
# Generate predictions on the test set for visualization.
final_predictions_lm_log <- predict(final_lm_model, newdata = test_data)
final_predictions_lm <- exp(final_predictions_lm_log)  # Convert predictions back to the original scale.

# --- Step 10: Plot Actual vs Predicted for Linear Model ---
# Open a window for the plot.
windows()
# Create a scatter plot to compare actual vs. predicted resale prices.
plot(test_data$resale_price, final_predictions_lm, 
     main = "Linear Model: Actual vs Predicted Resale Price",  # Title for the plot.
     xlab = "Actual Resale Price",  # Label for the x-axis.
     ylab = "Predicted Resale Price",  # Label for the y-axis.
     col = "blue",  # Set point color.
     pch = 16)  # Set point shape.

# Add a reference line to indicate perfect prediction (y = x).
abline(0, 1, col = "red", lwd = 2)  # Add a red line with slope 1 and intercept 0.

########## Decision Tree MODEL #################################################
set.seed(123456)  # Ensures that the results are consistent across different runs for reproducibility.

# REASON FOR RPART COMPARED TO TREE 
#This was chosen as it uses the Gini impurity, the purity based on of each node in deciding the splits. 
#This is computationally more efficient than Tree Package and supports more complex splitting methods.

# --- Step 1: Fit the Full Regression Tree Model ---
# Fit a regression tree using log-transformed resale price as the response variable, 

# A higher cp reduces the model's complexity, resulting in a simpler tree and potentially fewer 
#overfitting issues. However, to maintain a more accurate tree, the model was tested with lower cp’s 
#and was found that the difference in the RMSE, with (cp = 0.0001) and (cp = 0.00001) was insignificant. 
#Thus, (cp = 0.0001) was set initially and then the optimal cp was determined by plotting the “cptable”.
big.tree = rpart(resale_price_log ~ .-resale_price, method = "anova", data = train_data, cp = 0.0001)

# --- Step 2: Check the Number of Terminal Nodes ---
# Count the number of terminal nodes (leaves) in the tree to assess its size.
length(unique(big.tree$where))

# --- Step 3: Plot Cross-Validation Results to Identify Optimal CP ---
# Plot the cross-validation error to visualize where the minimum occurs and to identify potential overfitting.
plotcp(big.tree)

# --- Step 4: Identify the Best CP Based on Cross-Validation Error ---
# Extract the complexity parameter (cp) that minimizes the cross-validation error.
bestcp = big.tree$cptable[which.min(big.tree$cptable[,"xerror"]),"CP"]
cat("Best cp from CV:", bestcp, "\n")  # Display the chosen cp value for pruning.

# --- Step 5: Prune the Tree Using the Best CP ---
# Prune the large tree to the optimal size using the best cp value to reduce overfitting.
best.tree = prune(big.tree, cp = bestcp)

# --- Step 6: Predict on Test Data ---
# Generate predictions on the test set using the pruned tree model (log-transformed predictions).
tree_fit_log = predict(best.tree, newdata = test_data, type = "vector")
# Convert predictions back to the original price scale using the exponential function.
tree_fit = exp(tree_fit_log)

# --- Step 7: Calculate RMSE for Decision Tree on Test Data ---
# Calculate the RMSE to evaluate the model's predictive performance on the test data.
RMSE_tree = sqrt(mean((test_data$resale_price - tree_fit)^2))
cat("RMSE for Decision Tree:", RMSE_tree, "\n")

# --- Step 8: Define Cross-validation Function for Decision Tree ---
# Define a function for cross-validation that takes a subset of data (bootstrap sample) and evaluates the RMSE.
cv_tree <- function(data, indices) {
  # Subset the data using the bootstrap indices for training.
  train_data <- data[indices, ]
  # Use the remaining data as the test set.
  test_data <- data[-indices, ]
  # Fit the full regression tree on the training data.
  tree_model <- rpart(resale_price_log ~ .-resale_price, method = "anova", data = train_data, cp = bestcp)
  # Identify the best cp value for pruning based on cross-validation error.
  bestcp <- tree_model$cptable[which.min(tree_model$cptable[,"xerror"]),"CP"]
  # Prune the tree to the best size.
  pruned_tree <- prune(tree_model, cp = bestcp)
  # Make predictions on the test data (log-transformed).
  tree_pred_log <- predict(pruned_tree, newdata = test_data, type = "vector")
  # Convert predictions back to the original price scale.
  tree_pred <- exp(tree_pred_log)
  # Calculate and return RMSE for the current fold.
  rmse_val <- sqrt(mean((test_data$resale_price - tree_pred)^2))
  return(rmse_val)
}

# --- Step 9: Perform 10-fold Cross-validation for Decision Tree ---
# Use the `boot` package to perform 10-fold cross-validation and calculate RMSE for the model.
cv_results_tree <- boot(data = df, statistic = cv_tree, R = 10)

# --- Step 10: Calculate and display the mean RMSE from cross-validation ---
# Calculate the average RMSE across all folds to get a reliable estimate of model performance.
RMSE_tree_cv <- mean(cv_results_tree$t)
cat("Mean RMSE from 10-fold CV for Decision Tree: ", RMSE_tree_cv, "\n")

# --- Step 11: Refit the Final Decision Tree Model Using the Full Training Data ---
# Train the final decision tree model using the entire dataset with the optimal cp value.
final_tree_model <- rpart(resale_price_log ~ .-resale_price, method = "anova", data = df, cp = bestcp)
length(unique(final_tree_model$where))
best_tree_length <- length(unique(final_tree_model$where))
# Make predictions on the test data (log-transformed).
final_tree_fit_log <- predict(final_tree_model, newdata = test_data, type = "vector")
# Convert predictions to the original scale.
final_tree_fit <- exp(final_tree_fit_log)

# --- Step 12: Plot the Final Decision Tree ---
# Plot the final pruned decision tree after fitting it on the full training data.
# Plot the final decision tree using base R
windows()
plot(final_tree_model, 
     main = paste("Final Decision Tree Model (cp = ", round(bestcp, 5), ")"),
     uniform = TRUE, 
     branch = 1, 
     compress = TRUE, 
     margin = 0.1)
# Add text to the plot for nodes
text(final_tree_model, use.n = TRUE, cex = 0.8)

# --- Step 13: Plot Actual vs Predicted for Decision Tree ---
# Plot the actual resale prices against the predicted values to visually assess model performance.
windows()  # Opens a new graphics window.
plot(test_data$resale_price, final_tree_fit, 
     main = "Decision Tree: Actual vs Predicted Resale Price",
     xlab = "Actual Resale Price", 
     ylab = "Predicted Resale Price",
     col = "blue",  # Color of the points.
     pch = 16)      # Type of point marker.
# Add a reference line to indicate perfect prediction (y = x).
abline(0, 1, col = "red", lwd = 2)  # Add a red line with slope 1 and intercept 0.


########## k-NN MODEL ##########################################################
set.seed(123456)  # Ensures that the results are consistent across different runs for reproducibility.

# --- Step 1: Define a cross-validation function for k-NN to calculate RMSE for different k values ---
cv_kknn <- function(data, indices, k_value) {
  # Split the data into training and testing sets using the provided indices
  train_data <- data[indices, ]  # Training data subset
  test_data <- data[-indices, ]  # Testing data subset
  # Fit a k-NN model using the specified k value and log-transformed target variable
  knnpred <- kknn(resale_price_log ~ .-resale_price, train_data, test_data, k = k_value, kernel = "gaussian")
  # Extract predicted log-transformed values
  predicted_values_log <- knnpred$fitted.values
  # Transform predictions back to the original scale (exponentiation reverses the log transformation)
  predicted_values <- exp(predicted_values_log)
  # Calculate residuals (actual - predicted)
  actual_values <- test_data$resale_price
  residuals <- actual_values - predicted_values
  # Compute RMSE (Root Mean Squared Error)
  rmse_val <- sqrt(mean(residuals^2))
  return(rmse_val)
}

# --- Step 2: Set a range of k values to test ---
k_values <- 1:20  # Testing k from 1 to 20 to find the optimal k. Any higher k value would be computationally taxing.

# --- Step 3: Perform 10-fold cross-validation for each k ---
cv_results_kknn_all_k <- sapply(k_values, function(k) {
  # Apply bootstrapping to get 10-fold cross-validation RMSE for each k
  cv_results <- boot(data = train_data, 
                     statistic = function(data, indices) cv_kknn(data, indices, k), 
                     R = 10)  # R = 10 specifies 10-fold CV
  mean(cv_results$t)  # Calculate the mean RMSE across folds
})

# --- Step 4: Identify the best k value that minimizes RMSE ---
best_k <- k_values[which.min(cv_results_kknn_all_k)]  # Find k with minimum RMSE
cat("Best k value:", best_k, "\n")
cat("Minimum RMSE for the best k:", min(cv_results_kknn_all_k), "\n")

# --- Step 5: Fit k-NN model with the best k on the scaled training dataset ---
knnpred_best_k <- kknn(resale_price_log ~ .-resale_price, train_data, test_data, k = best_k, kernel = "gaussian")

# --- Step 6: Extract predictions from the fitted k-NN model ---
predicted_values_log_best_k <- knnpred_best_k$fitted.values

# --- Step 7: Transform the log-transformed predictions to the original scale ---
predicted_values_best_k <- exp(predicted_values_log_best_k)  # Undo log transformation

# --- Step 8: Calculate RMSE for k-NN predictions on test data ---
residuals_best_k <- test_data$resale_price - predicted_values_best_k  # Calculate residuals
RMSE_knn <- sqrt(mean(residuals_best_k^2))  # Compute RMSE
cat("k-NN RMSE with the best k:", RMSE_knn, "\n")

# --- Step 9: Define cross-validation function for k-NN to validate the model ---
cv_kknn_10fold <- function(data, indices, k_value) {
  # Split data into training and test sets using indices
  train_data <- data[indices, ]
  test_data <- data[-indices, ]
  # Fit k-NN model with the specified k
  knnpred <- kknn(resale_price_log ~ .-resale_price, train_data, test_data, k = k_value, kernel = "gaussian")
  # Extract predictions and transform to the original scale
  predicted_values_log <- knnpred$fitted.values
  predicted_values <- exp(predicted_values_log)
  # Compute residuals and RMSE
  actual_values <- test_data$resale_price
  residuals <- actual_values - predicted_values
  rmse_val <- sqrt(mean(residuals^2))
  return(rmse_val)
}

# --- Step 10: Perform 10-fold cross-validation for the best k ---
cv_results_kknn_10fold <- boot(data = df, 
                               statistic = function(data, indices) cv_kknn_10fold(data, indices, best_k), 
                               R = 10)  # 10-fold CV
RMSE_knn_cv <- mean(cv_results_kknn_10fold$t)  # Calculate mean RMSE
cat("Mean RMSE from 10-fold CV for k-NN with best k:", RMSE_knn_cv, "\n")

# --- Step 11: Refit the final k-NN model using the full training data set ---
final_knnpred_best_k <- kknn(resale_price_log ~ .-resale_price, train_data, test_data, k = best_k, kernel = "gaussian")
final_predicted_values_log_best_k <- final_knnpred_best_k$fitted.values

# --- Step 12: Transform the predictions to the original scale ---
final_predicted_values_best_k <- exp(final_predicted_values_log_best_k)  # Reverse log transformation

# --- Step 13: Plot actual vs. predicted resale prices ---
windows()  # Opens a new window for plotting
plot(test_data$resale_price, final_predicted_values_best_k, 
     main = paste("k-NN (k =", best_k, "): Actual vs Predicted Resale Price"),
     xlab = "Actual Resale Price", 
     ylab = "Predicted Resale Price",
     col = "blue", 
     pch = 16)  # Blue points for actual vs. predicted
# Add a reference line to indicate perfect prediction (y = x).
abline(0, 1, col = "red", lwd = 2)  # Add a red line with slope 1 and intercept 0.

########## PCA MODEL ###########################################################
set.seed(123456)  # Set seed for reproducibility to ensure consistent results across runs.

# --- Step 1: Calculate variance for each column except 'resale_price' ---
variances <- apply(df[, -which(names(df) == "resale_price")], 2, var)
# Identifying columns with zero variance helps remove redundant features.

# --- Step 2: Select columns with non-zero variance ---
non_zero_variance_columns <- names(variances[variances > 0])
# Only columns with non-zero variance are useful for PCA.

# --- Step 3: Prepare the dataset for PCA ---
df_clean <- df[, c(non_zero_variance_columns, "resale_price")]  # Keep columns with non-zero variance and 'resale_price'.
df_clean$resale_price_log <- log(df_clean$resale_price)  # Log-transform 'resale_price' to stabilize variance.
# Log transformation helps handle skewed data and improve model performance.

# --- Step 4: Split data into training and test sets ---
train_data_clean <- df_clean[train_indices, ]
test_data_clean <- df_clean[-train_indices, ]
# Splitting data ensures separate training and evaluation sets.

# --- Step 5: Remove constant columns and resale_price before scaling ---
train_data_no_constant <- train_data_clean[, !(names(train_data_clean) %in% c("resale_price")) & apply(train_data_clean, 2, var) > 0]
test_data_no_constant <- test_data_clean[, !(names(test_data_clean) %in% c("resale_price")) & apply(test_data_clean, 2, var) > 0]
# Remove constant columns and 'resale_price' to prevent issues during scaling and PCA.

# --- Step 6: Ensure both train and test sets have the same columns ---
common_columns <- intersect(names(train_data_no_constant), names(test_data_no_constant))
# Ensures consistency between training and test sets for PCA and modeling.

# --- Step 7: Scale the data (excluding 'resale_price_log') ---
train_data_scaled <- scale(train_data_no_constant[, common_columns])
test_data_scaled <- scale(test_data_no_constant[, common_columns])
# Standardize features to have mean 0 and standard deviation 1 for PCA.

# --- Step 8: Apply PCA to the scaled training data ---
pca_model <- prcomp(train_data_scaled, center = TRUE, scale. = TRUE)
# PCA reduces dimensionality by transforming correlated features into uncorrelated components.

# --- Step 9: Summarize the PCA model ---
summary(pca_model)
# Summarizing shows the variance explained by each principal component.
explained_variance <- (pca_model$sdev^2) / sum(pca_model$sdev^2)
# Create a bar plot of the explained variance
windows()  # Open a new window for the plot
barplot(explained_variance, 
        main = "Scree Plot (Explained Variance)", 
        col = "orange", 
        xlab = "Principal Components", 
        ylab = "Variance Explained", 
        names.arg = paste("PC", 1:length(explained_variance), sep = ""),
        las = 2,  # Rotate axis labels for readability
        cex.names = 0.8)  # Adjust label size if needed

# --- Step 10: Select the number of components that explain 95% variance ---
cumulative_variance <- cumsum(pca_model$sdev^2) / sum(pca_model$sdev^2)
num_components <- which(cumulative_variance >= 0.95)[1]
cat("Number of components that explain 95% variance: ", num_components, "\n")
# Selecting components that explain 95% of the variance ensures we're keeping the most informative ones.

# --- Step 11: Predict PCA components for training and test data ---
train_pca <- predict(pca_model, newdata = train_data_scaled)[, 1:num_components]
test_pca <- predict(pca_model, newdata = test_data_scaled)[, 1:num_components]
# Apply PCA transformation to both training and test data.

# --- Step 12: Combine PCA components with log-transformed 'resale_price' ---
train_pca_data <- cbind(train_pca, resale_price_log = train_data_clean$resale_price_log)
test_pca_data <- cbind(test_pca, resale_price_log = test_data_clean$resale_price_log)
# Combine PCA components with response variable for model training and testing.

# --- Step 13: Fit a linear model using the PCA components ---
lm_pca <- lm(resale_price_log ~ ., data = as.data.frame(train_pca_data))
summary(lm_pca)
# Fit a linear model to predict log-transformed 'resale_price' using PCA components.

# --- Step 14: Make predictions on the test set ---
pca_predictions_log <- predict(lm_pca, newdata = as.data.frame(test_pca_data))
pca_predictions <- exp(pca_predictions_log)  # Convert predictions back to original scale.
# Convert log-transformed predictions back to original scale.

# --- Step 15: Calculate RMSE for the PCA model ---
RMSE_pca <- sqrt(mean((test_data_clean$resale_price - pca_predictions)^2))
cat("RMSE for PCA Model: ", RMSE_pca, "\n")
# RMSE is a good metric to evaluate model performance.

# --- Step 16: Plot Actual vs. Predicted Resale Prices ---
windows()
plot(test_data_clean$resale_price, pca_predictions, 
     main = paste("PCA Model: Actual vs Predicted Resale Price"),
     xlab = "Actual Resale Price", 
     ylab = "Predicted Resale Price",
     col = "blue", 
     pch = 16)
abline(0, 1, col = "red", lwd = 2)  # Add a red reference line for perfect predictions.

########## Comparison of RMSE ##################################################

cat("Comparison of RMSE:\n")
cat("Linear Model (LM) RMSE:", RMSE_lm, "\n")
cat("Linear Model (LM) RMSE from CV:", RMSE_lm_cv, "\n")
cat("Decision Tree RMSE:", RMSE_tree, "\n")
cat("Decision Tree RMSE from CV:", RMSE_tree_cv, "\n")
cat("k-NN RMSE:", RMSE_knn, "\n")
cat("k-NN RMSE:", RMSE_knn_cv, "\n")
cat("PCA RMSE:", RMSE_pca, "\n")

comparison <- data.frame(
  Model = c("Linear Model (LM)", "Decision Tree", "k-NN", "PCA"),
  RMSE = c(RMSE_lm, RMSE_tree, RMSE_knn, RMSE_pca),
  CV_RMSE = c(RMSE_lm_cv, RMSE_tree_cv, RMSE_knn_cv, NA)  # Not applicable for Decision Tree and PCA
)

# Print the comparison table
print(comparison)
