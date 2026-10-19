# My portfolio website

A personal website that showcases my projects, experience, education and resume.

- **Public site** (what recruiters see): plain HTML/CSS/JavaScript in `docs/`, hosted free on **GitHub Pages**
- **Admin page** (only on my laptop): a small **Python + Flask** app for adding and editing projects
- **Builder**: `build.py` turns my data into the finished website

---

## How the pieces fit together

```
  You edit in the admin page          build.py fills the template          GitHub Pages publishes
  (admin/app.py, on your laptop)  →   (templates/index.html)          →   the docs/ folder online
            │                                   │
            └──── saves to data/site.json ──────┘
```

| File / folder | What it is |
|---|---|
| `data/site.json` | **All your content**: profile, projects, experience, education, skills |
| `admin/app.py` | The admin page (Python/Flask). Runs at http://127.0.0.1:5000 |
| `admin/templates/` | HTML for the admin screens |
| `build.py` | Reads `site.json` → writes the finished site into `docs/` |
| `templates/base.html` | Shared layout: top menu, fonts and contact footer on every page |
| `templates/index.html` | The home page (hero, about, project cards, experience, education, skills) |
| `templates/project.html` | The layout of each project's own page (`docs/projects/<name>/`) |
| `static/style.css` | All the colours, fonts and layout. Change `--accent` to re-colour the site |
| `static/main.js` | Interactive bits: project filters, dark mode, scroll effects |
| `static/projects/` | Cover images, reports and code for each project |
| `static/uploads/` | Images and resume PDF you upload through the admin page |
| `docs/` | **The finished website.** Generated automatically, so don't edit it by hand |
| `run_admin.bat` | Double-click to start the admin page on Windows |

---

## One-time setup (Windows)

### 1. Install the tools
1. **Python**: download from https://www.python.org/downloads/. During install, **tick "Add python.exe to PATH"**.
2. **Git**: download from https://git-scm.com/download/win and accept the defaults.
3. Open **Command Prompt** and check that both worked:
   ```
   python --version
   git --version
   ```

### 2. Install Flask (the Python library the admin page uses)
```
cd %USERPROFILE%\My-Projects
pip install -r requirements.txt
```

### 3. Tell Git who you are (first time only)
```
git config --global user.name "Your Name"
git config --global user.email "the-email-on-your-github-account@example.com"
```

### 4. Point this folder at your GitHub repo
The repo is now called **My-website**:
```
git remote set-url origin https://github.com/suryaaa03/My-website.git
git remote -v
```

### 5. First commit and push
```
git add .
git commit -m "First version of my portfolio website"
git push -u origin main
```
The first push opens a browser window asking you to **sign in to GitHub**. That's normal.

### 6. Turn on GitHub Pages
1. On GitHub, open the **My-website** repo → **Settings** → **Pages** (left menu).
2. Under **Build and deployment**, set **Source** to **Deploy from a branch**.
3. Set **Branch** to `main` and the folder to **`/docs`**, then click **Save**.
4. Wait 1–2 minutes, then refresh. Your link appears at the top:
   **https://suryaaa03.github.io/My-website/**

> ⚠️ The repo must be **Public** for free GitHub Pages (Settings → General → Danger Zone → Change visibility).

---

## Everyday use: adding a project

1. **Double-click `run_admin.bat`** (or run `python admin/app.py`). Your browser opens the admin page.
2. Click **+ Add project**, fill it in, and **Save**. Each project gets its own page with an overview, steps, results and downloadable files. The site rebuilds automatically.
3. Click **Preview site ↗** to see exactly what recruiters will see.
4. Close the black window (or press `Ctrl + C`) to stop the admin page.
5. Publish your changes:
   ```
   git add .
   git commit -m "Add <project name>"
   git push
   ```
   GitHub Pages updates in about a minute.

### What the three Git commands mean
- `git add .` — "I want to include all my changed files in the next snapshot."
- `git commit -m "..."` — "Take the snapshot and label it." It's saved on your laptop only.
- `git push` — "Upload my snapshots to GitHub." GitHub Pages then republishes the site.

---

## Tips
- **Good project entries:** a one-line summary of the problem, highlights with numbers ("cut processing time by 40%"), the tech used, a screenshot, and a GitHub or demo link.
- Tick **Featured** on your 2–3 best projects so they appear first.
- Upload your **resume PDF** in *Profile & skills* to get a "Download resume" button.
- Want a different colour? Change `--accent` near the top of `static/style.css`, then click **Rebuild**.
- Something broke? Run `git status` to see what changed, or `git log --oneline` to see your history.
