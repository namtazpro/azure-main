"""
Index + search tier for the drawing-extraction pipeline.

Takes the enriched JSON produced by extract_drawings.py, flattens it into one
search document per sheet, embeds the searchable text, and makes it queryable
with hybrid (keyword + vector) search.

Two interchangeable backends:
  * azure  - production: Azure OpenAI embeddings + Azure AI Search (REST).
  * local  - self-contained demo: deterministic hashing embeddings stored in
             SQLite, cosine + keyword scoring. Needs only numpy (runs offline).

Usage:
  python index_drawings.py index  BGSE_TBridge.enriched.json --backend local
  python index_drawings.py search "bolted gusset plate truss connection" --backend local
  python index_drawings.py index  BGSE_TBridge.enriched.json --backend azure
"""

import argparse
import hashlib
import json
import os
import re
import sqlite3
import sys

import numpy as np

EMB_DIM = 1024
LOCAL_DB = "drawing_index.sqlite"


# ---------------------------------------------------------------------------
# Document shaping
# ---------------------------------------------------------------------------
def build_documents(enriched):
    """One search document per sheet, plus a flattened searchable 'content'."""
    doc = enriched.get("document", {})
    project = doc.get("project_no") or "UNKNOWN"
    docs = []
    for s in enriched.get("sheets", []):
        vc = s.get("vision_caption") or {}
        views = [c.get("title") for c in s.get("view_callouts", []) if c.get("title")]
        xrefs = [f"{e['detail_no']}/{e['to_sheet']}" for e in s.get("cross_references", [])]
        components = list(s.get("components", {}).keys())
        members = vc.get("members_visible", [])
        connections = vc.get("connection_elements", [])
        materials = vc.get("materials", [])
        content = " | ".join(filter(None, [
            doc.get("title"), s.get("discipline_title"), vc.get("summary"),
            "Views: " + ", ".join(views) if views else "",
            "Members: " + ", ".join(members) if members else "",
            "Connections: " + ", ".join(connections) if connections else "",
            "Components: " + ", ".join(components) if components else "",
            "Materials: " + ", ".join(materials) if materials else "",
            "Dimensions: " + ", ".join(s.get("dimensions", [])) if s.get("dimensions") else "",
        ]))
        docs.append({
            "id": f"{project}-{s.get('sheet_id') or s['page']}",
            "project_no": project,
            "doc_title": doc.get("title"),
            "sheet_id": s.get("sheet_id"),
            "page": s.get("page"),
            "discipline_title": s.get("discipline_title"),
            "drawing_types": vc.get("drawing_types", []),
            "members_visible": members,
            "connection_elements": connections,
            "materials": materials,
            "components": components,
            "view_titles": views,
            "cross_references": xrefs,
            "summary": vc.get("summary"),
            "vision_confidence": vc.get("confidence"),
            "content": content,
        })
    return docs


# ---------------------------------------------------------------------------
# Local embedding backend (deterministic hashing vectorizer)
# ---------------------------------------------------------------------------
def _tokens(text):
    words = re.findall(r"[a-z0-9]+", (text or "").lower())
    bigrams = [f"{words[i]} {words[i + 1]}" for i in range(len(words) - 1)]
    return words + bigrams


def _bucket(tok, dim):
    h = int(hashlib.md5(tok.encode()).hexdigest(), 16)
    return h % dim, (1.0 if (h >> 17) & 1 else -1.0)


def embed_local(texts, dim=EMB_DIM):
    vecs = np.zeros((len(texts), dim), dtype=np.float32)
    for i, t in enumerate(texts):
        counts = {}
        for tok in _tokens(t):
            counts[tok] = counts.get(tok, 0) + 1
        for tok, c in counts.items():
            idx, sign = _bucket(tok, dim)
            vecs[i, idx] += sign * (1.0 + np.log(c))
        n = np.linalg.norm(vecs[i])
        if n:
            vecs[i] /= n
    return vecs


# ---------------------------------------------------------------------------
# Azure backends (production)
# ---------------------------------------------------------------------------
def embed_azure(texts):
    import requests
    endpoint = os.environ["AZURE_OPENAI_ENDPOINT"].rstrip("/")
    deployment = os.environ["AZURE_OPENAI_EMBED_DEPLOYMENT"]
    api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-06-01")
    url = f"{endpoint}/openai/deployments/{deployment}/embeddings?api-version={api_version}"
    r = requests.post(url, headers={"api-key": os.environ["AZURE_OPENAI_API_KEY"],
                                    "Content-Type": "application/json"},
                      json={"input": texts}, timeout=60)
    r.raise_for_status()
    return [d["embedding"] for d in r.json()["data"]]


def azure_search_request(method, path, body=None):
    import requests
    endpoint = os.environ["AZURE_SEARCH_ENDPOINT"].rstrip("/")
    api_version = os.environ.get("AZURE_SEARCH_API_VERSION", "2024-07-01")
    url = f"{endpoint}{path}?api-version={api_version}"
    r = requests.request(method, url,
                         headers={"api-key": os.environ["AZURE_SEARCH_API_KEY"],
                                  "Content-Type": "application/json"},
                         json=body, timeout=60)
    r.raise_for_status()
    return r.json() if r.text else {}


def azure_ensure_index(index_name, dim):
    """Create/replace an AI Search index with keyword + vector fields."""
    schema = {
        "name": index_name,
        "fields": [
            {"name": "id", "type": "Edm.String", "key": True, "filterable": True},
            {"name": "project_no", "type": "Edm.String", "filterable": True, "facetable": True},
            {"name": "sheet_id", "type": "Edm.String", "filterable": True},
            {"name": "page", "type": "Edm.Int32", "filterable": True, "sortable": True},
            {"name": "discipline_title", "type": "Edm.String", "searchable": True, "filterable": True},
            {"name": "drawing_types", "type": "Collection(Edm.String)", "searchable": True, "filterable": True, "facetable": True},
            {"name": "members_visible", "type": "Collection(Edm.String)", "searchable": True, "filterable": True, "facetable": True},
            {"name": "connection_elements", "type": "Collection(Edm.String)", "searchable": True, "filterable": True, "facetable": True},
            {"name": "components", "type": "Collection(Edm.String)", "searchable": True, "filterable": True, "facetable": True},
            {"name": "summary", "type": "Edm.String", "searchable": True},
            {"name": "content", "type": "Edm.String", "searchable": True},
            {"name": "contentVector", "type": "Collection(Edm.Single)",
             "searchable": True, "dimensions": dim,
             "vectorSearchProfile": "default-profile"},
        ],
        "vectorSearch": {
            "algorithms": [{"name": "hnsw-algo", "kind": "hnsw"}],
            "profiles": [{"name": "default-profile", "algorithm": "hnsw-algo"}],
        },
        "semantic": {
            "configurations": [{
                "name": "default-semantic",
                "prioritizedFields": {
                    "titleField": {"fieldName": "discipline_title"},
                    "prioritizedContentFields": [{"fieldName": "content"}],
                    "prioritizedKeywordsFields": [{"fieldName": "members_visible"}],
                },
            }],
        },
    }
    azure_search_request("PUT", f"/indexes/{index_name}", schema)


def azure_index(docs, index_name):
    azure_ensure_index(index_name, EMB_DIM)
    vectors = embed_azure([d["content"] for d in docs])
    payload = {"value": []}
    for d, v in zip(docs, vectors):
        payload["value"].append({"@search.action": "mergeOrUpload",
                                 "contentVector": v, **d})
    azure_search_request("POST", f"/indexes/{index_name}/docs/index", payload)
    return len(docs)


def azure_search(query, index_name, k):
    qvec = embed_azure([query])[0]
    body = {
        "search": query,                       # keyword (BM25)
        "vectorQueries": [{                     # vector
            "kind": "vector", "vector": qvec,
            "fields": "contentVector", "k": k,
        }],
        "queryType": "semantic",                # semantic re-rank fuses both
        "semanticConfiguration": "default-semantic",
        "top": k,
        "select": "id,sheet_id,page,discipline_title,summary",
    }
    res = azure_search_request("POST", f"/indexes/{index_name}/docs/search", body)
    return [(r.get("@search.score", 0.0), r) for r in res.get("value", [])]


# ---------------------------------------------------------------------------
# Local store (SQLite) + hybrid search
# ---------------------------------------------------------------------------
def local_index(docs, db=LOCAL_DB):
    vectors = embed_local([d["content"] for d in docs])
    con = sqlite3.connect(db)
    con.execute("CREATE TABLE IF NOT EXISTS docs (id TEXT PRIMARY KEY, json TEXT, vec BLOB, dim INT)")
    con.execute("DELETE FROM docs")
    for d, v in zip(docs, vectors):
        con.execute("INSERT OR REPLACE INTO docs VALUES (?,?,?,?)",
                    (d["id"], json.dumps(d), v.astype(np.float32).tobytes(), len(v)))
    con.commit()
    con.close()
    return len(docs)


def local_search(query, k, db=LOCAL_DB, alpha=0.7):
    con = sqlite3.connect(db)
    rows = con.execute("SELECT json, vec, dim FROM docs").fetchall()
    con.close()
    qvec = embed_local([query])[0]
    qtokens = set(_tokens(query))
    scored = []
    for js, vec, dim in rows:
        d = json.loads(js)
        v = np.frombuffer(vec, dtype=np.float32, count=dim)
        cos = float(np.dot(qvec, v))                       # both L2-normalised
        dtoks = set(_tokens(d["content"]))
        kw = len(qtokens & dtoks) / (len(qtokens) or 1)    # keyword overlap
        score = alpha * cos + (1 - alpha) * kw
        scored.append((score, cos, kw, d))
    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[:k]


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def cmd_index(args):
    enriched = json.load(open(args.enriched, encoding="utf-8"))
    docs = build_documents(enriched)
    if args.backend == "azure":
        n = azure_index(docs, args.index_name)
        print(f"Uploaded {n} sheet documents to Azure AI Search index '{args.index_name}'.")
    else:
        n = local_index(docs, args.db)
        print(f"Indexed {n} sheet documents into local store '{args.db}'.")


def cmd_search(args):
    if args.backend == "azure":
        results = azure_search(args.query, args.index_name, args.k)
        print(f"\nQuery: {args.query}\n" + "-" * 60)
        for score, r in results:
            print(f"[{score:5.3f}] {r.get('sheet_id')} p{r.get('page')} - {r.get('discipline_title')}")
            print(f"         {(r.get('summary') or '')[:140]}")
    else:
        results = local_search(args.query, args.k, args.db)
        print(f"\nQuery: {args.query}\n" + "-" * 60)
        for score, cos, kw, d in results:
            print(f"[{score:5.3f}  vec={cos:4.2f} kw={kw:4.2f}] "
                  f"{d['sheet_id']} p{d['page']} - {d['discipline_title']}")
            print(f"         {(d.get('summary') or '')[:140]}")


def main():
    ap = argparse.ArgumentParser(description="Embed + index + search drawing records.")
    ap.add_argument("--backend", choices=["local", "azure"], default="local")
    ap.add_argument("--index-name", default="drawings")
    ap.add_argument("--db", default=LOCAL_DB)
    ap.add_argument("--k", type=int, default=5)
    sub = ap.add_subparsers(dest="cmd", required=True)
    pi = sub.add_parser("index"); pi.add_argument("enriched")
    ps = sub.add_parser("search"); ps.add_argument("query")
    args = ap.parse_args()
    {"index": cmd_index, "search": cmd_search}[args.cmd](args)


if __name__ == "__main__":
    main()
