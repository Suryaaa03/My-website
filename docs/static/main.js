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

// ---------- 4. Click a project card -> pop-up with full details ----------
const dialog = document.getElementById("project-dialog");
const dialogBody = dialog.querySelector(".dialog-body");

cards.forEach((card) => {
  card.addEventListener("click", (event) => {
    if (event.target.closest("a")) return; // let "Code" / "Live demo" links work normally
    const detail = card.querySelector("template.detail");
    dialogBody.replaceChildren(detail.content.cloneNode(true));
    dialog.showModal();
  });
});
dialog.querySelector(".close").addEventListener("click", () => dialog.close());
// Clicking the dark area outside the pop-up also closes it.
dialog.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); });

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
const sections = [...links].map((a) => document.querySelector(a.getAttribute("href"))).filter(Boolean);
if ("IntersectionObserver" in window) {
  const spy = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        links.forEach((a) => a.classList.toggle("current", a.getAttribute("href") === "#" + entry.target.id));
      }
    });
  }, { rootMargin: "-45% 0px -50% 0px" });
  sections.forEach((s) => spy.observe(s));
}
