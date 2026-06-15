"""
Prototype drawing-set extractor for construction/engineering CAD PDFs.

Demonstrates an org-scale ingestion tier: from a single vector PDF it emits
structured JSON containing
  - document + per-sheet title-block metadata
  - general notes (codes / material specs)
  - the sheet index
  - view callouts (number, title, scale, view type)
  - a cross-reference graph between sheets (detail/sheet callouts)
  - component/member labels per sheet (controlled vocabulary)
  - dimension annotations

This is the "cheap, deterministic" tier that runs on every file. Vision-model
captioning of the drawing geometry would be a separate, selective tier.
"""

import argparse
import base64
import json
import os
import re
import sys
from collections import Counter

import fitz  # PyMuPDF

SHEET_ID_RE = re.compile(r"^(COV|S\d{1,2})$")
SCALE_RE = re.compile(r"SCALE:\s*(.+)", re.I)
DIM_RE = re.compile(r"\d+'-\s*\d+(?:\.\d+)?\"|\d+'-\d+\"")
DATE_RE = re.compile(r"\d{1,2}/\d{1,2}/\d{2,4}")
UPPER_TITLE_RE = re.compile(r"^[A-Z0-9][A-Z0-9 ,.&'\-/]{3,}$")

# Controlled vocabulary of structural components to tag for search.
COMPONENTS = [
    "Top Chord", "Bottom Chord", "Btm Chord", "Diagonal", "Vertical",
    "End Girder", "Girder", "Deck Beam", "Gusset Plate", "Connection Angle",
    "Foundation Pin", "Lattice Plate", "Channel", "Conc. Deck", "Conc. Slab",
    "Truss", "Bolt",
]

VIEW_TYPES = ["ISOMETRIC", "PLAN", "PROFILE", "SECTION", "FRONT VIEW",
              "TOP VIEW", "BTM VIEW", "DETAIL", "ELEVATION"]


def classify_view(title):
    t = title.upper()
    for vt in VIEW_TYPES:
        if vt in t:
            return vt.title()
    return "Other"


def parse_sheet_id(lines):
    # The authoritative sheet id sits in the title block, adjacent to the
    # project number ("TBRDG"). Picking the first S-code in reading order is
    # unreliable because cross-reference callouts (e.g. "2 / S3") appear earlier.
    for i, ln in enumerate(lines):
        if ln.strip() == "TBRDG":
            for j in (i - 1, i + 1, i + 2):
                if 0 <= j < len(lines) and SHEET_ID_RE.match(lines[j].strip()):
                    return lines[j].strip()
    for ln in lines:  # fallback
        if SHEET_ID_RE.match(ln.strip()):
            return ln.strip()
    return None


def parse_discipline_title(lines):
    # The discipline label sits next to the firm e-mail, but the CAD export
    # places it either just before or just after depending on the sheet.
    skip = {"--------", "------", "Revisions:", "Scale:"}
    for i, ln in enumerate(lines):
        if "QandA@alaska.com" in ln:
            for j in (i - 1, i + 1, i + 2):
                if 0 <= j < len(lines):
                    cand = lines[j].strip()
                    if cand and cand not in skip and UPPER_TITLE_RE.match(cand):
                        return cand
    return None


def parse_view_callouts(lines, sheet_id):
    """Anchor on each 'BGSCM: Bridge' marker; collect nearby number+title+scale."""
    callouts = []
    for i, ln in enumerate(lines):
        if "BGSCM" not in ln:
            continue
        window = lines[max(0, i - 2): i + 3]
        number = None
        for j in range(i + 1, min(i + 3, len(lines))):
            if lines[j].strip().isdigit():
                number = lines[j].strip()
                break
        title = None
        for cand in lines[i + 1: i + 4] + lines[max(0, i - 2): i]:
            c = cand.strip()
            if (UPPER_TITLE_RE.match(c) and not c.startswith("SCALE")
                    and not c.isdigit() and c != "TBRDG"):
                title = c
                break
        scale = None
        for cand in window:
            m = SCALE_RE.search(cand)
            if m:
                scale = m.group(1).strip()
                break
        if title:
            callouts.append({
                "sheet": sheet_id,
                "view_no": number,
                "title": title,
                "scale": scale,
                "view_type": classify_view(title),
            })
    # de-dup (the PDF layer-stacks some callouts twice)
    seen, uniq = set(), []
    for c in callouts:
        key = (c["sheet"], c["view_no"], c["title"])
        if key not in seen:
            seen.add(key)
            uniq.append(c)
    return uniq


def parse_xrefs(lines, sheet_id):
    """A detail callout is a small integer line followed by a sheet code line."""
    edges = []
    for i in range(len(lines) - 1):
        a, b = lines[i].strip(), lines[i + 1].strip()
        if a.isdigit() and 1 <= int(a) <= 6 and re.match(r"^S\d{1,2}$", b):
            if b != sheet_id:  # exclude the title-block self/total slot
                edges.append({"from_sheet": sheet_id, "detail_no": a, "to_sheet": b})
    seen, uniq = set(), []
    for e in edges:
        key = (e["from_sheet"], e["detail_no"], e["to_sheet"])
        if key not in seen:
            seen.add(key)
            uniq.append(e)
    return uniq


def parse_components(text):
    found = Counter()
    for comp in COMPONENTS:
        n = len(re.findall(re.escape(comp), text, re.I))
        if n:
            found[comp] = n
    return dict(found)


def parse_general_notes(text):
    notes = []
    if "General Notes:" not in text:
        return notes
    body = text.split("General Notes:", 1)[1]
    body = re.split(r"A Beginner's Guide", body, 1)[0]
    # notes are numbered "1." "2." ...
    parts = re.split(r"\n\s*\d+\.\s*\n", "\n" + body)
    for p in parts:
        p = " ".join(p.split())
        if len(p) > 25:
            notes.append(p)
    return notes


def parse_sheet_index(text):
    idx = []
    if "Sheet Index:" not in text:
        return idx
    body = text.split("Sheet Index:", 1)[1]
    body = re.split(r"A Beginner's Guide|Copyright", body, 1)[0]
    for m in re.finditer(r"(S\d(?:-S\d)?|COV)\s*\n\s*([A-Za-z][^\n]+)", body):
        idx.append({"sheet": m.group(1).strip(), "description": m.group(2).strip()})
    return idx


# ---------------------------------------------------------------------------
# Vision tier: render each sheet and request a structured caption from a
# multimodal model. This is the selective / higher-cost tier.
# ---------------------------------------------------------------------------

VISION_PROMPT = (
    "You are a structural/civil engineering drawing analyst. Look at this single "
    "sheet from a CAD drawing set and describe ONLY what is visually depicted in the "
    "drawing geometry (not the title block). Respond as strict JSON with keys: "
    "summary (string, 1-3 sentences), drawing_types (array, e.g. Isometric/Plan/"
    "Section/Detail), members_visible (array of structural members), "
    "connection_elements (array, e.g. gusset plate, bolts, weld, angle), "
    "materials (array), annotations_dimensions (array of notable dims/notes), "
    "confidence (0-1 float). Use the discipline vocabulary of steel/concrete design."
)


def render_page_png(page, dpi=150):
    zoom = dpi / 72.0
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom))
    return pix.tobytes("png")


def caption_azure_openai(png_bytes, context_hint=""):
    """Call an Azure OpenAI vision-capable deployment. Requires env vars:
    AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_KEY, AZURE_OPENAI_DEPLOYMENT
    (and optionally AZURE_OPENAI_API_VERSION). Returns a parsed caption dict."""
    import requests  # imported lazily so offline/inject mode needs no dependency

    endpoint = os.environ["AZURE_OPENAI_ENDPOINT"].rstrip("/")
    deployment = os.environ["AZURE_OPENAI_DEPLOYMENT"]
    api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-06-01")
    url = (f"{endpoint}/openai/deployments/{deployment}/chat/completions"
           f"?api-version={api_version}")
    b64 = base64.b64encode(png_bytes).decode("ascii")
    body = {
        "messages": [
            {"role": "system", "content": VISION_PROMPT},
            {"role": "user", "content": [
                {"type": "text", "text": f"Sheet context: {context_hint}"},
                {"type": "image_url",
                 "image_url": {"url": f"data:image/png;base64,{b64}"}},
            ]},
        ],
        "max_tokens": 700,
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    r = requests.post(url, headers={"api-key": os.environ["AZURE_OPENAI_API_KEY"],
                                    "Content-Type": "application/json"},
                      json=body, timeout=90)
    r.raise_for_status()
    content = r.json()["choices"][0]["message"]["content"]
    return json.loads(content)


def caption_sheets(doc, sheets, backend="azure", dpi=150, render_dir=None):
    """Produce a vision caption per page using the chosen backend."""
    captions = []
    for page in doc:
        png = render_page_png(page, dpi)
        if render_dir:
            os.makedirs(render_dir, exist_ok=True)
            with open(os.path.join(render_dir, f"page{page.number + 1}.png"), "wb") as f:
                f.write(png)
        sid = next((s["sheet_id"] for s in sheets if s["page"] == page.number + 1), None)
        hint = f"sheet {sid}" if sid else f"page {page.number + 1}"
        cap = {"page": page.number + 1}
        if backend == "azure":
            try:
                cap.update(caption_azure_openai(png, hint))
            except Exception as exc:  # keep the pipeline resilient at scale
                cap.update({"error": str(exc), "summary": None, "confidence": 0.0})
        captions.append(cap)
    return captions


def load_injected_captions(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return {c["page"]: c for c in data.get("captions", [])}


def extract(path, vision=False, vision_backend="azure", vision_dpi=150,
            render_dir=None, captions_file=None):
    doc = fitz.open(path)
    full_text = "\n".join(p.get_text() for p in doc)

    sheets, all_callouts, all_xrefs = [], [], []
    for page in doc:
        text = page.get_text()
        lines = text.splitlines()
        sid = parse_sheet_id(lines)
        sheet = {
            "page": page.number + 1,
            "sheet_id": sid,
            "discipline_title": parse_discipline_title(lines),
            "scales": sorted(set(m.group(1).strip() for m in
                                 (SCALE_RE.search(l) for l in lines) if m)),
            "dimensions": sorted(set(DIM_RE.findall(text))),
            "components": parse_components(text),
        }
        callouts = parse_view_callouts(lines, sid)
        xrefs = parse_xrefs(lines, sid)
        sheet["view_callouts"] = callouts
        sheet["cross_references"] = xrefs
        sheets.append(sheet)
        all_callouts += callouts
        all_xrefs += xrefs

    meta = doc.metadata
    project_no = None
    m = re.search(r"\bTBRDG\b", full_text)
    if m:
        project_no = "TBRDG"
    dates = DATE_RE.findall(full_text)

    # --- vision tier: attach a per-sheet caption ------------------------------
    vision_meta = {"enabled": vision}
    if vision:
        if captions_file:
            injected = load_injected_captions(captions_file)
            vision_meta["source"] = f"injected:{os.path.basename(captions_file)}"
            for s in sheets:
                s["vision_caption"] = injected.get(s["page"])
        else:
            caps = caption_sheets(doc, sheets, vision_backend, vision_dpi, render_dir)
            by_page = {c["page"]: c for c in caps}
            vision_meta["source"] = f"backend:{vision_backend}"
            for s in sheets:
                s["vision_caption"] = by_page.get(s["page"])
        if render_dir:
            vision_meta["render_dir"] = render_dir

    return {
        "source_file": path,
        "document": {
            "title": "Peters Creek Bridge",
            "project_no": project_no,
            "page_count": doc.page_count,
            "drawn_by": "TBQ" if "TBQ" in full_text else None,
            "firm": "Quimby & Associates, Consulting Engineers",
            "revision_date": dates[0] if dates else None,
            "cad_producer": meta.get("creator") or meta.get("producer"),
            "pdf_created": meta.get("creationDate"),
            "is_vector": any(len(p.get_text().strip()) > 50 for p in doc),
        },
        "general_notes": parse_general_notes(full_text),
        "sheet_index": parse_sheet_index(full_text),
        "sheets": sheets,
        "cross_reference_graph": all_xrefs,
        "view_callouts": all_callouts,
        "vision": vision_meta,
        "component_index": dict(sorted(
            Counter({k: v for s in sheets for k, v in s["components"].items()}).items())),
    }


def main():
    ap = argparse.ArgumentParser(description="Extract structured metadata from a CAD PDF drawing set.")
    ap.add_argument("pdf")
    ap.add_argument("-o", "--out", help="write JSON to this file")
    ap.add_argument("--vision", action="store_true",
                    help="enable the vision-captioning tier")
    ap.add_argument("--vision-backend", default="azure", choices=["azure"],
                    help="multimodal backend to use when not injecting captions")
    ap.add_argument("--vision-dpi", type=int, default=150,
                    help="render resolution for vision captioning")
    ap.add_argument("--render-dir", help="also save rendered sheet PNGs here")
    ap.add_argument("--captions-file",
                    help="merge pre-computed captions (JSON) instead of calling the backend")
    args = ap.parse_args()
    data = extract(args.pdf, vision=args.vision, vision_backend=args.vision_backend,
                   vision_dpi=args.vision_dpi, render_dir=args.render_dir,
                   captions_file=args.captions_file)
    out = json.dumps(data, indent=2)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(out)
        print(f"Wrote {args.out}")
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
