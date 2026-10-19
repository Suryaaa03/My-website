// =========================================================
// main.js - the interactive parts of the website.
// Runs in the visitor's browser (no server needed).
// =========================================================

document.documentElement.classList.add("js");

// ---------- 1. Light / dark theme toggle ----------
const root = document.documentElement;
document.getElementById("theme-toggle").addEventListener("click", () => {
  const isDark = root.dataset.theme
    ? root.dataset.theme === "dark"
    : window.matchMedia("(prefers-color-scheme: dark)").matches;
  root.dataset.theme = isDark ? "light" : "dark";
  try { localStorage.setItem("theme", root.dataset.theme); } catch (e) { /* storage blocked: fine */ }
});

// ---------- 2. Nav gets a border once you scroll ----------
const nav = document.querySelector(".nav");
const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 8);
window.addEventListener("scroll", onScroll, { passive: true });
onScroll();

// ---------- 3. Project filter buttons ----------
const chips = document.querySelectorAll(".chip");
const cards = document.querySelectorAll(".card");
chips.forEach((chip) => {
  chip.addEventListener("click", () => {
    chips.forEach((c) => c.classList.remove("active"));
    chip.classList.add("active");
    const filter = chip.dataset.filter;
    cards.forEach((card) => {
      card.classList.toggle("hidden", filter !== "all" && card.dataset.category !== filter);
    });
  });
});

// ---------- 4. Project cards ----------
// Each card's title is a link; CSS stretches it over the whole card, so clicking anywhere opens the project page.

// ---------- 5. Fade sections in as you scroll ----------
const revealEls = document.querySelectorAll(".reveal");
if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("in");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  revealEls.forEach((el) => observer.observe(el));
} else {
  revealEls.forEach((el) => el.classList.add("in"));
}

// ---------- 6. Highlight the nav link for the section on screen ----------
const links = document.querySelectorAll(".nav nav a");
const hashOf = (a) => "#" + a.getAttribute("href").split("#")[1];
const sections = [...links].map((a) => document.querySelector(hashOf(a))).filter(Boolean);
if ("IntersectionObserver" in window) {
  const spy = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        links.forEach((a) => a.classList.toggle("current", hashOf(a) === "#" + entry.target.id));
      }
    });
  }, { rootMargin: "-45% 0px -50% 0px" });
  sections.forEach((s) => spy.observe(s));
}

// ---------- 7. Lightbox: gallery images and figures open on this page, not a new tab ----------
(function () {
  const links = [...document.querySelectorAll("a.lb")];
  if (!links.length) return;
  const overlay = document.createElement("div");
  overlay.className = "lb-overlay";
  overlay.hidden = true;
  overlay.setAttribute("role", "dialog");
  overlay.setAttribute("aria-modal", "true");
  overlay.setAttribute("aria-label", "Image viewer");
  overlay.innerHTML =
    '<button class="lb-btn lb-close" type="button" aria-label="Close">✕</button>' +
    '<button class="lb-btn lb-prev" type="button" aria-label="Previous image">‹</button>' +
    '<button class="lb-btn lb-next" type="button" aria-label="Next image">›</button>' +
    '<figure><img alt=""><figcaption></figcaption></figure>';
  document.body.appendChild(overlay);
  const img = overlay.querySelector("img");
  const cap = overlay.querySelector("figcaption");
  const prev = overlay.querySelector(".lb-prev");
  const next = overlay.querySelector(".lb-next");
  let index = 0, lastFocus = null;

  function show(i) {
    index = (i + links.length) % links.length;
    const a = links[index];
    img.src = a.getAttribute("href");
    img.alt = a.dataset.caption || "";
    cap.textContent = a.dataset.caption || "";
    prev.hidden = next.hidden = links.length < 2;
  }
  function open(i) {
    lastFocus = document.activeElement;
    show(i);
    overlay.hidden = false;
    document.body.style.overflow = "hidden";
    overlay.querySelector(".lb-close").focus();
  }
  function close() {
    overlay.hidden = true;
    document.body.style.overflow = "";
    if (lastFocus) lastFocus.focus();
  }
  links.forEach((a, i) => a.addEventListener("click", (e) => { e.preventDefault(); open(i); }));
  overlay.querySelector(".lb-close").addEventListener("click", close);
  prev.addEventListener("click", () => show(index - 1));
  next.addEventListener("click", () => show(index + 1));
  overlay.addEventListener("click", (e) => { if (e.target === overlay) close(); });
  document.addEventListener("keydown", (e) => {
    if (overlay.hidden) return;
    if (e.key === "Escape") close();
    if (e.key === "ArrowLeft") show(index - 1);
    if (e.key === "ArrowRight") show(index + 1);
  });
})();

// ---------- 8. Skill bubbles: tap a skill to see a plain-English explanation ----------
(function () {
  const buttons = document.querySelectorAll(".skill-btn[aria-expanded]");
  function closeAll(except) {
    buttons.forEach((b) => {
      if (b === except) return;
      b.setAttribute("aria-expanded", "false");
      b.nextElementSibling.hidden = true;
    });
  }
  buttons.forEach((btn) => {
    const bubble = btn.nextElementSibling;
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const opening = btn.getAttribute("aria-expanded") !== "true";
      closeAll(btn);
      btn.setAttribute("aria-expanded", String(opening));
      bubble.hidden = !opening;
      if (opening) {
        // Keep the bubble on screen: flip it to the left edge if it would overflow on the right.
        bubble.classList.remove("align-right");
        const r = bubble.getBoundingClientRect();
        if (r.right > window.innerWidth - 12) bubble.classList.add("align-right");
      }
    });
  });
  document.addEventListener("click", () => closeAll(null));
  document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeAll(null); });
})();

// ---------- 9. Experience journey: "What I did" toggles ----------
document.querySelectorAll(".stop-toggle").forEach((btn) => {
  btn.addEventListener("click", () => {
    const open = btn.getAttribute("aria-expanded") !== "true";
    btn.setAttribute("aria-expanded", String(open));
    btn.nextElementSibling.hidden = !open;
  });
});
