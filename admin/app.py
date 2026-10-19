"""
admin/app.py - your private admin page, built with Flask (a Python web framework).

It runs ONLY on your own laptop (http://127.0.0.1:5000). Recruiters never see it.
Everything you add here is saved into data/site.json, and the public website
in docs/ is rebuilt automatically after every save.

Start it with:   python admin/app.py
"""

import json
import sys
import uuid
from pathlib import Path

from flask import (Flask, abort, flash, redirect, render_template, request,
                   send_from_directory, url_for)
from werkzeug.utils import secure_filename

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
import build  # noqa: E402  (our own build.py)

DATA_FILE = ROOT / "data" / "site.json"
UPLOADS = ROOT / "static" / "uploads"
IMAGE_TYPES = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
FILE_TYPES = IMAGE_TYPES | {".pdf", ".py", ".r", ".ipynb", ".xlsx", ".xls", ".csv", ".pptx", ".docx", ".zip", ".txt", ".md"}

app = Flask(__name__)
app.secret_key = "local-admin-only"  # only used for the little "Saved!" messages


# ---------------------------------------------------------------------------
# Each section of your resume is described here once. The same form template
# (entry_form.html) draws the right inputs for any section from this list.
# Field types: text, url, textarea, lines (one item per line),
#              list (comma separated), select, checkbox, image
# ---------------------------------------------------------------------------
SECTIONS = {
    "projects": {
        "title": "Project",
        "fields": [
            {"name": "title", "label": "Project name", "type": "text", "required": True},
            {"name": "category", "label": "Category", "type": "select",
             "options": ["University", "Personal", "Work", "Competition", "Other"]},
            {"name": "year", "label": "When (e.g. 2025, or Mar – May 2025)", "type": "text"},
            {"name": "summary", "label": "One-line summary (shown on the card)", "type": "text", "required": True},
            {"name": "role", "label": "My role (e.g. Team lead · built the forecasting models)", "type": "text"},
            {"name": "team", "label": "Team (e.g. Team of 4, or Individual)", "type": "text"},
            {"name": "description", "label": "Overview: the problem and why it matters (blank line = new paragraph)", "type": "textarea"},
            {"name": "approach", "label": "What I did: one step per line", "type": "lines"},
            {"name": "highlights", "label": "Results: one per line (numbers are great)", "type": "lines"},
            {"name": "tech", "label": "Tech used (comma separated, e.g. Python, Pandas, Flask)", "type": "list"},
            {"name": "github_url", "label": "GitHub link", "type": "url"},
            {"name": "demo_url", "label": "Live demo link", "type": "url"},
            {"name": "image", "label": "Cover image (shown on the card and at the top of the project page)", "type": "image"},
            {"name": "files", "label": "Files: reports, code, slides, extra screenshots (images appear in a gallery)", "type": "files"},
            {"name": "featured", "label": "Feature this project (shown first, with a badge)", "type": "checkbox"},
        ],
    },
    "experience": {
        "title": "Experience",
        "fields": [
            {"name": "role", "label": "Role / title", "type": "text", "required": True},
            {"name": "org", "label": "Organisation", "type": "text", "required": True},
            {"name": "start", "label": "Start (e.g. Jan 2024)", "type": "text"},
            {"name": "end", "label": "End (e.g. Present)", "type": "text"},
            {"name": "summary", "label": "Short summary", "type": "textarea"},
            {"name": "bullets", "label": "Key points (one per line)", "type": "lines"},
        ],
    },
    "education": {
        "title": "Education",
        "fields": [
            {"name": "school", "label": "School / university", "type": "text", "required": True},
            {"name": "qualification", "label": "Qualification (e.g. BSc Computer Science)", "type": "text"},
            {"name": "start", "label": "Start", "type": "text"},
            {"name": "end", "label": "End (or Expected 2027)", "type": "text"},
            {"name": "details", "label": "Details: modules, awards, CCAs (one per line)", "type": "lines"},
        ],
    },
}


# ------------------------------ helpers ------------------------------------
def load():
    return json.loads(DATA_FILE.read_text(encoding="utf-8"))


def save(data):
    """Save the data file, then rebuild the public website."""
    DATA_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    build.build()


def save_upload(field_name, allowed, f=None):
    """Store an uploaded file in static/uploads/ and return its path, or None."""
    f = f or request.files.get(field_name)
    if not f or not f.filename:
        return None
    ext = Path(f.filename).suffix.lower()
    if ext not in allowed:
        flash(f"Skipped {f.filename}: file type {ext} isn't allowed.", "error")
        return None
    UPLOADS.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex[:8]}-{secure_filename(f.filename)}"
    f.save(UPLOADS / name)
    return f"uploads/{name}"


def read_form(section, existing):
    """Turn the submitted form into a dictionary for one entry."""
    entry = dict(existing)
    for field in SECTIONS[section]["fields"]:
        name, kind = field["name"], field["type"]
        if kind == "checkbox":
            entry[name] = name in request.form
        elif kind == "lines":
            entry[name] = [l.strip() for l in request.form.get(name, "").splitlines() if l.strip()]
        elif kind == "list":
            entry[name] = [s.strip() for s in request.form.get(name, "").split(",") if s.strip()]
        elif kind == "files":
            kept = []
            for i, item in enumerate(existing.get(name) or []):
                if request.form.get(f"remove_{name}_{i}"):
                    continue
                label = request.form.get(f"label_{name}_{i}", "").strip() or item["label"]
                kept.append({"label": label, "path": item["path"]})
            for upload in request.files.getlist(name):
                path = save_upload(name, FILE_TYPES, upload)
                if path:
                    label = Path(upload.filename).stem.replace("_", " ").replace("-", " ")
                    kept.append({"label": label, "path": path})
            entry[name] = kept
        elif kind == "image":
            uploaded = save_upload(name, IMAGE_TYPES)
            if uploaded:
                entry[name] = uploaded
            elif request.form.get(f"remove_{name}"):
                entry[name] = ""
            else:
                entry.setdefault(name, "")
        else:
            entry[name] = request.form.get(name, "").strip()
    return entry


def find(items, entry_id):
    for i, item in enumerate(items):
        if item.get("id") == entry_id:
            return i, item
    abort(404)


# ------------------------------ pages --------------------------------------
@app.route("/")
def dashboard():
    return render_template("dashboard.html", data=load(), sections=SECTIONS)


@app.route("/profile", methods=["GET", "POST"])
def profile():
    data = load()
    if request.method == "POST":
        p = data["profile"]
        for key in ["name", "headline", "location", "about", "email", "linkedin", "github"]:
            p[key] = request.form.get(key, "").strip()
        p["open_to_work"] = "open_to_work" in request.form

        photo = save_upload("photo", IMAGE_TYPES)
        if photo:
            p["photo"] = photo
        elif request.form.get("remove_photo"):
            p["photo"] = ""

        resume = save_upload("resume_file", {".pdf"})
        if resume:
            p["resume_file"] = resume
        elif request.form.get("remove_resume_file"):
            p["resume_file"] = ""

        # Skills are typed as lines like:  Languages: Python, Java, SQL
        skills = []
        for line in request.form.get("skills", "").splitlines():
            if ":" in line:
                group, items = line.split(":", 1)
                items = [s.strip() for s in items.split(",") if s.strip()]
                if group.strip() and items:
                    skills.append({"group": group.strip(), "items": items})
        data["skills"] = skills

        save(data)
        flash("Profile saved and website rebuilt.", "ok")
        return redirect(url_for("dashboard"))

    skills_text = "\n".join(f"{s['group']}: {', '.join(s['items'])}" for s in data["skills"])
    return render_template("profile.html", p=data["profile"], skills_text=skills_text)


@app.route("/<section>/new", methods=["GET", "POST"])
@app.route("/<section>/<entry_id>/edit", methods=["GET", "POST"])
def edit_entry(section, entry_id=None):
    if section not in SECTIONS:
        abort(404)
    data = load()
    items = data.setdefault(section, [])
    index, existing = find(items, entry_id) if entry_id else (None, {"id": uuid.uuid4().hex[:10]})

    if request.method == "POST":
        entry = read_form(section, existing)
        if section == "projects" and not entry.get("slug"):
            # The slug is the project's web address (projects/<slug>/). It's set once
            # and kept, so links you've shared keep working even if you rename the project.
            taken = {p.get("slug") for p in items}
            slug = base = build.slugify(entry.get("title", ""))
            n = 2
            while slug in taken:
                slug, n = f"{base}-{n}", n + 1
            entry["slug"] = slug
        if index is None:
            items.append(entry)
        else:
            items[index] = entry
        save(data)
        flash(f"{SECTIONS[section]['title']} saved and website rebuilt.", "ok")
        return redirect(url_for("dashboard") + f"#{section}")

    return render_template("entry_form.html", section=section, spec=SECTIONS[section],
                           entry=existing, is_new=index is None)


@app.route("/<section>/<entry_id>/delete", methods=["POST"])
def delete_entry(section, entry_id):
    if section not in SECTIONS:
        abort(404)
    data = load()
    index, _ = find(data[section], entry_id)
    data[section].pop(index)
    save(data)
    flash("Deleted and website rebuilt.", "ok")
    return redirect(url_for("dashboard") + f"#{section}")


@app.route("/<section>/<entry_id>/move/<direction>", methods=["POST"])
def move_entry(section, entry_id, direction):
    if section not in SECTIONS:
        abort(404)
    data = load()
    items = data[section]
    i, _ = find(items, entry_id)
    j = i - 1 if direction == "up" else i + 1
    if 0 <= j < len(items):
        items[i], items[j] = items[j], items[i]
        save(data)
    return redirect(url_for("dashboard") + f"#{section}")


@app.route("/rebuild", methods=["POST"])
def rebuild():
    build.build()
    flash("Website rebuilt.", "ok")
    return redirect(url_for("dashboard"))


# Preview the finished public site exactly as recruiters will see it.
@app.route("/preview/")
@app.route("/preview/<path:filename>")
def preview(filename="index.html"):
    if not (build.OUT / "index.html").exists():
        build.build()
    return send_from_directory(build.OUT, filename)


if __name__ == "__main__":
    build.build()
    print("\nAdmin page running at  http://127.0.0.1:5000")
    print("Press Ctrl+C to stop.\n")
    # host 127.0.0.1 = only reachable from this laptop, never from the internet
    app.run(host="127.0.0.1", port=5000, debug=True)
