"""
build.py - turns your data (data/site.json) into a finished website (docs/).

How it works:
  1. Read all your info from data/site.json
  2. Fill it into the HTML templates in templates/ (using Jinja2):
       - templates/index.html   -> docs/index.html               (home page)
       - templates/project.html -> docs/projects/<slug>/index.html (one page per project)
  3. Copy the static/ folder (CSS, JavaScript, images, PDFs) next to them

GitHub Pages then publishes the docs/ folder as your public website.

Run it yourself with:   python build.py
(The admin page also runs it automatically every time you save.)
"""

import json
import re
import shutil
from datetime import date
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

ROOT = Path(__file__).resolve().parent      # the folder this file lives in
DATA_FILE = ROOT / "data" / "site.json"     # where your content is stored
TEMPLATES = ROOT / "templates"              # the HTML "shape" of the site
STATIC = ROOT / "static"                    # CSS, JavaScript, images, files
OUT = ROOT / "docs"                         # the finished website (published)

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"}


def slugify(text):
    """'Weather Humidity Prediction!' -> 'weather-humidity-prediction' (used in page URLs)."""
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-") or "project"


def load_data():
    with open(DATA_FILE, encoding="utf-8") as f:
        return json.load(f)


def prepare_projects(projects):
    """Add the extra info templates need: a unique slug, and files split into images vs downloads."""
    used = set()
    for p in projects:
        slug = p.get("slug") or slugify(p.get("title", ""))
        while slug in used:
            slug += "-2"
        used.add(slug)
        p["slug"] = slug
        files = p.get("files") or []
        p["gallery"] = [f for f in files if Path(f["path"]).suffix.lower() in IMAGE_EXTS]
        p["downloads"] = [f for f in files if Path(f["path"]).suffix.lower() not in IMAGE_EXTS]
        p["ext"] = {f["path"]: Path(f["path"]).suffix.lstrip(".").upper() for f in files}
    # Featured projects first, otherwise keep the order you chose in the admin page.
    return sorted(projects, key=lambda p: not p.get("featured"))


def prepare_skills(skills):
    """Each skill can be a plain name or {"name": ..., "note": ...}. Make them all the second kind."""
    for group in skills:
        group["items"] = [i if isinstance(i, dict) else {"name": i, "note": ""} for i in group.get("items", [])]
    return skills


def prepare_semesters(courses):
    """Group courses by semester (keeping your order) for the Learning journey timeline.
    A semester label looks like: "Year 1 · Semester 1 · AY2024/25 (Aug – Dec 2024)"."""
    semesters = []
    for c in courses:
        if not semesters or semesters[-1]["label"] != c.get("semester", ""):
            label = c.get("semester", "")
            parts = [x.strip() for x in label.split("·")]
            short = " · ".join(parts[:2]).replace("Semester", "Sem") if len(parts) >= 2 else label
            dates = parts[2] if len(parts) >= 3 else ""
            semesters.append({"label": label, "short": short, "dates": dates, "courses": [], "skills": [], "in_progress": False})
        sem = semesters[-1]
        sem["courses"].append(c)
        if c.get("status") == "In progress":
            sem["in_progress"] = True
        for k in c.get("skills", []):
            if k not in sem["skills"]:
                sem["skills"].append(k)
    return semesters


def build():
    data = load_data()
    projects = prepare_projects(data.get("projects", []))

    # The filter buttons on the home page: one per category that actually has projects.
    categories = []
    for p in projects:
        cat = p.get("category") or "Other"
        if cat not in categories:
            categories.append(cat)

    env = Environment(loader=FileSystemLoader(TEMPLATES), autoescape=select_autoescape())
    common = dict(
        profile=data.get("profile", {}),
        skills=prepare_skills(data.get("skills", [])),
        semesters=prepare_semesters(data.get("courses", [])),
        experience=data.get("experience", []),
        education=data.get("education", []),
        projects=projects,
        categories=categories,
        year=date.today().year,
    )

    # Start from a clean docs/ folder each time so deleted files don't linger.
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()

    # Home page (root = "" because it sits at the top of the site)
    html = env.get_template("index.html").render(root="", **common)
    (OUT / "index.html").write_text(html, encoding="utf-8")

    # One page per project, at docs/projects/<slug>/index.html (root = "../../")
    project_tpl = env.get_template("project.html")
    for i, p in enumerate(projects):
        page_dir = OUT / "projects" / p["slug"]
        page_dir.mkdir(parents=True)
        neighbours = {
            "prev": projects[i - 1] if i > 0 else None,
            "next": projects[i + 1] if i < len(projects) - 1 else None,
        }
        html = project_tpl.render(root="../../", p=p, **neighbours, **common)
        (page_dir / "index.html").write_text(html, encoding="utf-8")

    shutil.copytree(STATIC, OUT / "static")
    # Tells GitHub Pages to serve files as-is (no extra processing).
    (OUT / ".nojekyll").write_text("", encoding="utf-8")

    return OUT / "index.html"


if __name__ == "__main__":
    path = build()
    print(f"Website built: {path}")
    print("Open that file in your browser to preview it.")
