"""
build.py - turns your data (data/site.json) into a finished website (docs/).

How it works:
  1. Read all your info from data/site.json
  2. Fill it into the HTML template in templates/index.html (using Jinja2)
  3. Write the result to docs/index.html and copy the static/ folder next to it

GitHub Pages then publishes the docs/ folder as your public website.

Run it yourself with:   python build.py
(The admin page also runs it automatically every time you save.)
"""

import json
import shutil
from datetime import date
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

ROOT = Path(__file__).resolve().parent      # the folder this file lives in
DATA_FILE = ROOT / "data" / "site.json"     # where your content is stored
TEMPLATES = ROOT / "templates"              # the HTML "shape" of the site
STATIC = ROOT / "static"                    # CSS, JavaScript, images, resume
OUT = ROOT / "docs"                         # the finished website (published)


def load_data():
    with open(DATA_FILE, encoding="utf-8") as f:
        return json.load(f)


def build():
    data = load_data()

    # Featured projects first, otherwise keep the order you chose in the admin page.
    projects = sorted(data.get("projects", []), key=lambda p: not p.get("featured"))

    # The filter buttons on the site: one per category that actually has projects.
    categories = []
    for p in projects:
        cat = p.get("category") or "Other"
        if cat not in categories:
            categories.append(cat)

    env = Environment(loader=FileSystemLoader(TEMPLATES), autoescape=select_autoescape())
    html = env.get_template("index.html").render(
        profile=data.get("profile", {}),
        skills=data.get("skills", []),
        experience=data.get("experience", []),
        education=data.get("education", []),
        projects=projects,
        categories=categories,
        year=date.today().year,
    )

    # Start from a clean docs/ folder each time so deleted images don't linger.
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    (OUT / "index.html").write_text(html, encoding="utf-8")
    shutil.copytree(STATIC, OUT / "static")
    # Tells GitHub Pages to serve files as-is (no extra processing).
    (OUT / ".nojekyll").write_text("", encoding="utf-8")

    return OUT / "index.html"


if __name__ == "__main__":
    path = build()
    print(f"Website built: {path}")
    print("Open that file in your browser to preview it.")
