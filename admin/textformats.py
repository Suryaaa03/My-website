"""
textformats.py - lets you edit mind maps, tables and charts as plain text in the admin page.

Each structure has two functions:
    *_to_text(data)  -> the text shown in the admin form
    parse_*(text)    -> the data saved into site.json
They are exact opposites, so editing and saving never loses information.

------------------------------------------------------------------ MIND MAP
One branch per line:   Branch name: item; item; item

------------------------------------------------------------------ TABLES
Separate tables with a blank line.
    # Table title
    Column 1 | Column 2 | Column 3
    Row label | value | value
    * Best row | value | value        <- a leading * highlights the row
    > A note shown under the table    <- optional

------------------------------------------------------------------ CHARTS
Separate charts with a blank line. The first line is the title.
Optional settings line:  @ lower-is-better, prefix=$, suffix=%, decimals=0, highlight-column=2
    Bar chart:      Label: 123        (* Label: 123 highlights a bar)
                    ref Share price: 3670      <- dashed reference line
    Grouped chart:  groups: 1 hour, 6 hours, 24 hours
                    Series name: 0.054, 0.070, 0.086
    Range chart:    Label: 26.10 - 67.15       (* Label: ... highlights)
                    marker Share price: 52.76  (marker* ... highlights)
    > note text
"""


# ------------------------------------------------------------- helpers
def _num(text):
    text = text.strip().replace(",", "").replace("−", "-")
    value = float(text)
    return int(value) if value.is_integer() and "." not in text else value


def _fmt(value):
    return f"{value:g}" if isinstance(value, float) else str(value)


def _blocks(text):
    """Split text into blocks separated by blank lines."""
    blocks, current = [], []
    for line in (text or "").replace("\r", "").split("\n"):
        if line.strip():
            current.append(line.rstrip())
        elif current:
            blocks.append(current)
            current = []
    if current:
        blocks.append(current)
    return blocks


# ------------------------------------------------------------- mind map
def mindmap_to_text(branches):
    return "\n".join(f"{b['label']}: {'; '.join(b.get('items', []))}" for b in branches or [])


def parse_mindmap(text):
    branches = []
    for line in (text or "").splitlines():
        if not line.strip():
            continue
        label, _, rest = line.partition(":")
        items = [i.strip() for i in rest.split(";") if i.strip()]
        branches.append({"label": label.strip(), "items": items})
    return branches


# ------------------------------------------------------------- tables
def tables_to_text(tables):
    out = []
    for t in tables or []:
        lines = []
        if t.get("title"):
            lines.append(f"# {t['title']}")
        if t.get("highlight_col") is not None:
            lines.append(f"@ highlight-column={t['highlight_col']}")
        lines.append(" | ".join(t.get("columns", [])))
        hl = set(t.get("highlight") or [])
        for i, row in enumerate(t.get("rows", [])):
            lines.append(("* " if i in hl else "") + " | ".join(row))
        if t.get("note"):
            lines.append(f"> {t['note']}")
        out.append("\n".join(lines))
    return "\n\n".join(out)


def parse_tables(text):
    tables = []
    for block in _blocks(text):
        t = {"title": "", "columns": [], "rows": []}
        for line in block:
            s = line.strip()
            if s.startswith("#"):
                t["title"] = s.lstrip("#").strip()
            elif s.startswith("@"):
                for opt in s[1:].split(","):
                    key, _, val = opt.strip().partition("=")
                    if key == "highlight-column" and val.strip().isdigit():
                        t["highlight_col"] = int(val)
            elif s.startswith(">"):
                t["note"] = s[1:].strip()
            elif not t["columns"]:
                t["columns"] = [c.strip() for c in s.split("|")]
            else:
                if s.startswith("* "):
                    t.setdefault("highlight", []).append(len(t["rows"]))
                    s = s[2:]
                t["rows"].append([c.strip() for c in s.split("|")])
        if t["columns"]:
            tables.append(t)
    return tables


# ------------------------------------------------------------- charts
def charts_to_text(charts):
    out = []
    for c in charts or []:
        lines = [c.get("title", "Chart")]
        opts = []
        if c.get("lower_is_better"):
            opts.append("lower-is-better")
        for key in ("prefix", "suffix"):
            if c.get(key):
                opts.append(f"{key}={c[key]}")
        if c.get("decimals") is not None:
            opts.append(f"decimals={c['decimals']}")
        if opts:
            lines.append("@ " + ", ".join(opts))
        kind = c.get("type", "bar")
        if kind == "grouped":
            lines.append("groups: " + ", ".join(c.get("groups", [])))
            for s in c.get("series", []):
                lines.append(f"{s['label']}: " + ", ".join(_fmt(v) for v in s["values"]))
        elif kind == "range":
            for b in c.get("bars", []):
                lines.append(f"{'* ' if b.get('accent') else ''}{b['label']}: {_fmt(b['low'])} - {_fmt(b['high'])}")
            for m in c.get("markers", []):
                lines.append(f"marker{'*' if m.get('accent') else ''} {m['label']}: {_fmt(m['value'])}")
        else:
            for b in c.get("bars", []):
                lines.append(f"{'* ' if b.get('accent') else ''}{b['label']}: {_fmt(b['value'])}")
            if c.get("reference"):
                lines.append(f"ref {c['reference']['label']}: {_fmt(c['reference']['value'])}")
        if c.get("note"):
            lines.append(f"> {c['note']}")
        out.append("\n".join(lines))
    return "\n\n".join(out)


def parse_charts(text):
    charts = []
    for block in _blocks(text):
        c = {"type": "bar", "title": block[0].strip()}
        bars, series, markers = [], [], []
        for line in block[1:]:
            s = line.strip()
            if s.startswith("@"):
                for opt in s[1:].split(","):
                    key, _, val = opt.strip().partition("=")
                    if key == "lower-is-better":
                        c["lower_is_better"] = True
                    elif key in ("prefix", "suffix"):
                        c[key] = val
                    elif key == "decimals" and val.strip().isdigit():
                        c["decimals"] = int(val)
                continue
            if s.startswith(">"):
                c["note"] = s[1:].strip()
                continue
            if s.lower().startswith("groups:"):
                c["type"] = "grouped"
                c["groups"] = [g.strip() for g in s.split(":", 1)[1].split(",") if g.strip()]
                continue
            accent = s.startswith("* ")
            if accent:
                s = s[2:]
            label, _, value = s.rpartition(":")
            label, value = label.strip(), value.strip()
            if not label:
                continue
            try:
                if label.lower().startswith("marker"):
                    is_acc = label[6:7] == "*"
                    m = {"label": label[7 if is_acc else 6:].strip(), "value": _num(value)}
                    if is_acc:
                        m["accent"] = True
                    markers.append(m)
                elif label.lower().startswith("ref "):
                    c["reference"] = {"label": label[4:].strip(), "value": _num(value)}
                elif c["type"] == "grouped":
                    series.append({"label": label, "values": [_num(v) for v in value.split(",")]})
                elif " - " in value:
                    low, high = value.split(" - ", 1)
                    b = {"label": label, "low": _num(low), "high": _num(high)}
                    if accent:
                        b["accent"] = True
                    bars.append(b)
                else:
                    b = {"label": label, "value": _num(value)}
                    if accent:
                        b["accent"] = True
                    bars.append(b)
            except ValueError:
                continue  # skip lines that aren't numbers
        if c["type"] == "grouped":
            c["series"] = series
        else:
            if bars and "low" in bars[0]:
                c["type"] = "range"
                c["markers"] = markers
            c["bars"] = bars
        charts.append(c)
    return charts


# ------------------------------------------------------------- skills
def skills_to_text(skills):
    groups, notes = [], []
    for g in skills or []:
        names = []
        for item in g.get("items", []):
            name = item["name"] if isinstance(item, dict) else item
            names.append(name)
            note = item.get("note") if isinstance(item, dict) else ""
            if note:
                notes.append(f"{name} = {note}")
        groups.append(f"{g['group']}: {'; '.join(names)}")
    return "\n".join(groups), "\n".join(notes)


def parse_skills(groups_text, notes_text):
    notes = {}
    for line in (notes_text or "").splitlines():
        if "=" in line:
            name, _, note = line.partition("=")
            notes[name.strip()] = note.strip()
    skills = []
    for line in (groups_text or "").splitlines():
        if ":" not in line:
            continue
        group, _, items = line.partition(":")
        names = [s.strip() for s in items.split(";") if s.strip()]
        if group.strip() and names:
            skills.append({"group": group.strip(), "items": [{"name": n, "note": notes.get(n, "")} for n in names]})
    return skills
