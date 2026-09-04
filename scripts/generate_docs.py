#!/usr/bin/env python3
"""Single-command documentation builder for molars.

1. Runs `mojo doc -I . molars` to extract AST docstrings and writes `docs/api-reference.md`.
2. Bundles all documentation guides and references into the interactive `docs/index.html` portal.
"""

import json
import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
DOCS_DIR = ROOT_DIR / "docs"
API_MD_FILE = DOCS_DIR / "api-reference.md"
HTML_OUTPUT = DOCS_DIR / "index.html"

SECTIONS = [
    {
        "id": "overview",
        "title": "Overview",
        "category": "Getting Started",
        "path": DOCS_DIR / "index.md",
        "icon": "home",
    },
    {
        "id": "getting-started",
        "title": "Quickstart Guide",
        "category": "Getting Started",
        "path": DOCS_DIR / "getting-started.md",
        "icon": "rocket",
    },
    {
        "id": "dataframe",
        "title": "DataFrame API",
        "category": "Core Guides",
        "path": DOCS_DIR / "dataframe.md",
        "icon": "table",
    },
    {
        "id": "series",
        "title": "Series API & SIMD",
        "category": "Core Guides",
        "path": DOCS_DIR / "series.md",
        "icon": "columns",
    },
    {
        "id": "sql",
        "title": "SQL Query Engine",
        "category": "Core Guides",
        "path": DOCS_DIR / "sql.md",
        "icon": "database",
    },
    {
        "id": "arrow-abi",
        "title": "Arrow C Data Interface",
        "category": "Internals",
        "path": DOCS_DIR / "arrow-abi.md",
        "icon": "cpu",
    },
    {
        "id": "architecture",
        "title": "Architecture & Memory",
        "category": "Internals",
        "path": ROOT_DIR / "ARCHITECTURE.md",
        "icon": "layers",
    },
    {
        "id": "api-reference",
        "title": "Auto API Reference",
        "category": "Reference",
        "path": API_MD_FILE,
        "icon": "code",
    },
]


def run_mojo_doc() -> dict:
    cmd = ["mojo", "doc", "-I", ".", "molars"]
    res = subprocess.run(cmd, cwd=ROOT_DIR, capture_output=True, text=True, check=True)
    return json.loads(res.stdout)


def format_docstring(summary: str, description: str) -> str:
    parts = []
    if summary:
        parts.append(summary.strip())
    if description:
        parts.append(description.strip())
    return "\n\n".join(parts)


def generate_markdown(doc_json: dict) -> str:
    lines = [
        "# API Reference (Auto-Generated)",
        "",
        "*Generated from source docstrings via `mojo doc`.*",
        "",
    ]

    decl = doc_json.get("decl", {})
    modules = decl.get("modules", [])

    for module in sorted(modules, key=lambda m: m.get("name", "")):
        mod_name = module.get("name", "")
        if mod_name.startswith("__"):
            continue

        lines.append(f"## Module `molars.{mod_name}`\n")

        structs = module.get("structs", [])
        for st in sorted(structs, key=lambda s: s.get("name", "")):
            st_name = st.get("name", "")
            lines.append(f"### `struct {st_name}`\n")

            traits = [t.get("name") for t in st.get("parentTraits", []) if t.get("name")]
            if traits:
                lines.append(f"**Implemented Traits**: `{', '.join(traits)}`\n")

            summary = format_docstring(st.get("summary", ""), st.get("description", ""))
            if summary:
                lines.append(f"{summary}\n")

            functions = st.get("functions", [])
            if functions:
                lines.append("#### Methods\n")

            for fn in functions:
                for ov in fn.get("overloads", []):
                    sig = ov.get("signature", "")
                    fn_summary = format_docstring(ov.get("summary", ""), ov.get("description", ""))

                    lines.append(f"##### `{sig}`\n")
                    if fn_summary:
                        lines.append(f"{fn_summary}\n")

                    args = [a for a in ov.get("args", []) if a.get("name") != "self"]
                    if args:
                        lines.append("**Arguments:**\n")
                        for arg in args:
                            a_name = arg.get("name", "")
                            a_type = arg.get("type", "")
                            a_desc = arg.get("description", "").strip()
                            type_str = f" (`{a_type}`)" if a_type else ""
                            desc_str = f": {a_desc}" if a_desc else ""
                            lines.append(f"- `{a_name}`{type_str}{desc_str}")
                        lines.append("")

                    ret = ov.get("returns")
                    if ret and (ret.get("type") or ret.get("doc")):
                        ret_type = ret.get("type", "")
                        ret_doc = ret.get("doc", "").strip()
                        lines.append(
                            f"**Returns:** `{ret_type}`"
                            + (f" - {ret_doc}" if ret_doc else "")
                            + "\n"
                        )

                    if ov.get("raises") and ov.get("raisesDoc"):
                        lines.append(f"**Raises:** {ov.get('raisesDoc').strip()}\n")

                    lines.append("---\n")

    return "\n".join(lines)


def load_docs_data() -> dict:
    data = {}
    for s in SECTIONS:
        path = s["path"]
        if path.exists():
            data[s["id"]] = {
                "title": s["title"],
                "category": s["category"],
                "content": path.read_text(encoding="utf-8"),
                "icon": s["icon"],
            }
        else:
            data[s["id"]] = {
                "title": s["title"],
                "category": s["category"],
                "content": f"# {s['title']}\n\n*Documentation pending.*",
                "icon": s["icon"],
            }
    return data


def generate_html(docs_data: dict) -> str:
    json_data = json.dumps(docs_data)

    return f"""<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>molars &mdash; Polars DataFrame for Mojo</title>
  <meta name="description" content="Native zero-copy Polars DataFrame bindings for Mojo via Apache Arrow C Data Interface">

  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">

  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/tokyo-night-dark.min.css">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>

  <style>
    :root {{
      --bg-primary: #090d16;
      --bg-secondary: #0e1626;
      --bg-surface: rgba(18, 28, 47, 0.65);
      --bg-card: rgba(22, 34, 56, 0.7);
      --border-color: rgba(255, 255, 255, 0.08);
      --border-hover: rgba(56, 189, 248, 0.35);

      --text-main: #f1f5f9;
      --text-muted: #94a3b8;
      --text-sub: #64748b;

      --cyan: #38bdf8;
      --cyan-glow: rgba(56, 189, 248, 0.2);
      --flame: #f97316;
      --purple: #c084fc;
      --emerald: #34d399;

      --sidebar-width: 280px;
      --toc-width: 240px;
      --header-height: 64px;
      --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      --font-mono: 'JetBrains Mono', ui-monospace, SFMono-Regular, monospace;
    }}

    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }}

    body {{
      font-family: var(--font-sans);
      background-color: var(--bg-primary);
      color: var(--text-main);
      line-height: 1.65;
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
    }}

    ::-webkit-scrollbar {{
      width: 6px;
      height: 6px;
    }}
    ::-webkit-scrollbar-track {{
      background: transparent;
    }}
    ::-webkit-scrollbar-thumb {{
      background: rgba(255, 255, 255, 0.15);
      border-radius: 999px;
    }}
    ::-webkit-scrollbar-thumb:hover {{
      background: rgba(255, 255, 255, 0.3);
    }}

    header {{
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      height: var(--header-height);
      background: rgba(9, 13, 22, 0.82);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border-bottom: 1px solid var(--border-color);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 28px;
      z-index: 100;
    }}

    .logo-container {{
      display: flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
      color: inherit;
      cursor: pointer;
    }}

    .logo-text {{
      font-size: 18px;
      font-weight: 700;
      letter-spacing: -0.3px;
      color: #ffffff;
    }}

    .version-badge {{
      font-size: 11px;
      font-weight: 600;
      padding: 2px 8px;
      border-radius: 999px;
      background: rgba(56, 189, 248, 0.12);
      color: var(--cyan);
      border: 1px solid rgba(56, 189, 248, 0.25);
    }}

    .header-actions {{
      display: flex;
      align-items: center;
      gap: 14px;
    }}

    .search-trigger {{
      display: flex;
      align-items: center;
      gap: 10px;
      background: var(--bg-surface);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 6px 14px;
      color: var(--text-muted);
      font-size: 13px;
      cursor: pointer;
      transition: all 0.2s ease;
      min-width: 220px;
    }}

    .search-trigger:hover {{
      border-color: var(--border-hover);
      color: var(--text-main);
      box-shadow: 0 0 12px rgba(56, 189, 248, 0.1);
    }}

    .search-kbd {{
      margin-left: auto;
      font-size: 10px;
      background: rgba(255, 255, 255, 0.08);
      padding: 2px 6px;
      border-radius: 4px;
      border: 1px solid rgba(255, 255, 255, 0.12);
      font-family: var(--font-mono);
    }}

    .gh-link {{
      color: var(--text-muted);
      text-decoration: none;
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 13px;
      padding: 6px 12px;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border-color);
      transition: all 0.2s ease;
    }}

    .gh-link:hover {{
      color: #fff;
      border-color: rgba(255, 255, 255, 0.2);
    }}

    .app-layout {{
      display: flex;
      margin-top: var(--header-height);
      min-height: calc(100vh - var(--header-height));
    }}

    aside.sidebar {{
      width: var(--sidebar-width);
      position: fixed;
      top: var(--header-height);
      bottom: 0;
      left: 0;
      background: var(--bg-secondary);
      border-right: 1px solid var(--border-color);
      overflow-y: auto;
      padding: 24px 16px;
      z-index: 50;
    }}

    .nav-category {{
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      color: var(--text-sub);
      margin: 20px 10px 8px 10px;
    }}
    .nav-category:first-of-type {{
      margin-top: 4px;
    }}

    .nav-item {{
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 12px;
      border-radius: 8px;
      color: var(--text-muted);
      text-decoration: none;
      font-size: 13.5px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.15s ease;
      margin-bottom: 2px;
    }}

    .nav-item:hover {{
      color: var(--text-main);
      background: rgba(255, 255, 255, 0.04);
    }}

    .nav-item.active {{
      color: var(--cyan);
      background: rgba(56, 189, 248, 0.1);
      border: 1px solid rgba(56, 189, 248, 0.25);
      font-weight: 600;
    }}

    main.content-area {{
      margin-left: var(--sidebar-width);
      margin-right: var(--toc-width);
      flex: 1;
      padding: 44px 56px 80px 56px;
      max-width: 960px;
    }}

    aside.toc {{
      width: var(--toc-width);
      position: fixed;
      top: var(--header-height);
      bottom: 0;
      right: 0;
      padding: 36px 20px;
      overflow-y: auto;
      border-left: 1px solid var(--border-color);
    }}

    .toc-title {{
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      color: var(--text-sub);
      margin-bottom: 12px;
    }}

    .toc-list {{
      list-style: none;
    }}

    .toc-link {{
      display: block;
      font-size: 12.5px;
      color: var(--text-muted);
      text-decoration: none;
      padding: 4px 0;
      transition: color 0.15s ease;
      line-height: 1.4;
    }}

    .toc-link:hover {{
      color: var(--cyan);
    }}
    .toc-link.indent {{
      padding-left: 14px;
      font-size: 12px;
    }}

    .markdown-body h1 {{
      font-size: 34px;
      font-weight: 800;
      letter-spacing: -0.8px;
      color: #fff;
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--border-color);
    }}

    .markdown-body h2 {{
      font-size: 22px;
      font-weight: 700;
      letter-spacing: -0.4px;
      color: #f8fafc;
      margin-top: 36px;
      margin-bottom: 14px;
      padding-bottom: 6px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    }}

    .markdown-body h3 {{
      font-size: 18px;
      font-weight: 600;
      color: #e2e8f0;
      margin-top: 24px;
      margin-bottom: 10px;
    }}

    .markdown-body h4 {{
      font-size: 15px;
      font-weight: 600;
      color: var(--cyan);
      margin-top: 18px;
      margin-bottom: 8px;
    }}

    .markdown-body h5 {{
      font-size: 14px;
      font-weight: 600;
      color: #f8fafc;
      margin-top: 16px;
      margin-bottom: 6px;
      font-family: var(--font-mono);
      background: rgba(255, 255, 255, 0.03);
      padding: 6px 10px;
      border-radius: 6px;
      border-left: 3px solid var(--cyan);
    }}

    .markdown-body p {{
      margin-bottom: 16px;
      color: #cbd5e1;
      font-size: 15px;
    }}

    .markdown-body ul, .markdown-body ol {{
      margin-bottom: 18px;
      padding-left: 24px;
      color: #cbd5e1;
    }}

    .markdown-body li {{
      margin-bottom: 6px;
      font-size: 14.5px;
    }}

    .markdown-body a {{
      color: var(--cyan);
      text-decoration: none;
      border-bottom: 1px dotted rgba(56, 189, 248, 0.4);
      transition: all 0.15s ease;
    }}

    .markdown-body a:hover {{
      border-bottom-color: var(--cyan);
      text-shadow: 0 0 8px var(--cyan-glow);
    }}

    .markdown-body code:not(pre code) {{
      background: rgba(255, 255, 255, 0.08);
      color: #fca5a5;
      padding: 2px 6px;
      border-radius: 4px;
      font-family: var(--font-mono);
      font-size: 13.5px;
      border: 1px solid rgba(255, 255, 255, 0.05);
    }}

    .code-container {{
      position: relative;
      margin: 20px 0;
      border-radius: 10px;
      overflow: hidden;
      border: 1px solid var(--border-color);
      background: #0f141c;
      box-shadow: 0 6px 24px rgba(0, 0, 0, 0.35);
    }}

    .code-header {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 16px;
      background: rgba(255, 255, 255, 0.03);
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
      font-family: var(--font-mono);
      font-size: 11px;
      color: var(--text-sub);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }}

    .copy-btn {{
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: var(--text-muted);
      border-radius: 5px;
      padding: 3px 8px;
      font-size: 11px;
      cursor: pointer;
      font-family: var(--font-sans);
      transition: all 0.2s ease;
    }}

    .copy-btn:hover {{
      background: var(--cyan);
      color: #000;
      font-weight: 600;
    }}

    .markdown-body pre {{
      margin: 0;
      padding: 16px 20px;
      overflow-x: auto;
      font-family: var(--font-mono);
      font-size: 13.5px;
      line-height: 1.6;
    }}

    .markdown-body table {{
      width: 100%;
      border-collapse: collapse;
      margin: 24px 0;
      border-radius: 8px;
      overflow: hidden;
      border: 1px solid var(--border-color);
      background: var(--bg-card);
    }}

    .markdown-body th {{
      background: rgba(255, 255, 255, 0.05);
      color: #fff;
      font-weight: 600;
      text-align: left;
      padding: 10px 16px;
      font-size: 13.5px;
      border-bottom: 1px solid var(--border-color);
    }}

    .markdown-body td {{
      padding: 10px 16px;
      font-size: 13.5px;
      color: #cbd5e1;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    }}

    .markdown-body tr:last-child td {{
      border-bottom: none;
    }}

    .markdown-body hr {{
      border: none;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      margin: 32px 0;
    }}

    .modal-overlay {{
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.75);
      backdrop-filter: blur(8px);
      z-index: 1000;
      align-items: flex-start;
      justify-content: center;
      padding-top: 10vh;
    }}

    .modal-overlay.open {{
      display: flex;
    }}

    .search-modal {{
      background: #0f172a;
      border: 1px solid var(--border-hover);
      box-shadow: 0 20px 48px rgba(0, 0, 0, 0.6);
      width: 100%;
      max-width: 620px;
      border-radius: 12px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }}

    .search-input-box {{
      display: flex;
      align-items: center;
      padding: 16px 20px;
      border-bottom: 1px solid var(--border-color);
      gap: 12px;
    }}

    .search-input-box input {{
      flex: 1;
      background: transparent;
      border: none;
      outline: none;
      color: #fff;
      font-size: 16px;
      font-family: var(--font-sans);
    }}

    .search-results {{
      max-height: 400px;
      overflow-y: auto;
      padding: 8px;
    }}

    .search-item {{
      padding: 10px 14px;
      border-radius: 8px;
      cursor: pointer;
      display: flex;
      flex-direction: column;
      gap: 4px;
      transition: background 0.15s ease;
    }}

    .search-item:hover, .search-item.selected {{
      background: rgba(56, 189, 248, 0.12);
    }}

    .search-item-title {{
      font-size: 14px;
      font-weight: 600;
      color: #fff;
    }}

    .search-item-snippet {{
      font-size: 12px;
      color: var(--text-muted);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }}

    @media (max-width: 1080px) {{
      aside.toc {{
        display: none;
      }}
      main.content-area {{
        margin-right: 0;
      }}
    }}

    @media (max-width: 768px) {{
      aside.sidebar {{
        display: none;
      }}
      main.content-area {{
        margin-left: 0;
        padding: 24px 20px;
      }}
    }}
  </style>
</head>
<body>

  <header>
    <div class="logo-container" onclick="navigate('overview')">
      <div class="logo-text">molars</div>
      <span class="version-badge">v0.1.0</span>
    </div>

    <div class="header-actions">
      <div class="search-trigger" onclick="openSearch()">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
        <span>Search documentation...</span>
        <span class="search-kbd">⌘K</span>
      </div>

      <a href="https://github.com/ethqnol/polars-mojo" target="_blank" class="gh-link">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/></svg>
        <span>GitHub</span>
      </a>
    </div>
  </header>

  <div class="app-layout">
    <aside class="sidebar">
      <div id="sidebar-nav"></div>
    </aside>

    <main class="content-area">
      <div id="markdown-container" class="markdown-body"></div>
    </main>

    <aside class="toc">
      <div class="toc-title">On This Page</div>
      <ul id="toc-list" class="toc-list"></ul>
    </aside>
  </div>

  <div class="modal-overlay" id="search-modal" onclick="closeSearchOnOverlay(event)">
    <div class="search-modal">
      <div class="search-input-box">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
        <input type="text" id="modal-search-input" placeholder="Search functions, types, keywords..." oninput="handleSearch(this.value)">
      </div>
      <div class="search-results" id="search-results">
        <div style="padding: 24px; text-align: center; color: var(--text-sub); font-size: 13px;">Type a query to search documentation...</div>
      </div>
    </div>
  </div>

  <script>
    const DOCS_DATA = {json_data};

    marked.setOptions({{
      highlight: function(code, lang) {{
        const language = highlight.getLanguage(lang) ? lang : 'plaintext';
        return highlight.highlight(code, {{ language }}).value;
      }},
      langPrefix: 'hljs language-'
    }});

    function buildSidebar() {{
      const navContainer = document.getElementById('sidebar-nav');
      navContainer.innerHTML = '';

      const categories = {{}};
      Object.keys(DOCS_DATA).forEach(id => {{
        const item = DOCS_DATA[id];
        if (!categories[item.category]) {{
          categories[item.category] = [];
        }}
        categories[item.category].push({{ id, ...item }});
      }});

      Object.keys(categories).forEach(cat => {{
        const catHeader = document.createElement('div');
        catHeader.className = 'nav-category';
        catHeader.textContent = cat;
        navContainer.appendChild(catHeader);

        categories[cat].forEach(item => {{
          const a = document.createElement('a');
          a.className = 'nav-item';
          a.id = `nav-${{item.id}}`;
          a.textContent = item.title;
          a.onclick = () => navigate(item.id);
          navContainer.appendChild(a);
        }});
      }});
    }}

    function navigate(sectionId) {{
      if (!DOCS_DATA[sectionId]) sectionId = 'overview';
      window.location.hash = sectionId;

      document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
      const activeNav = document.getElementById(`nav-${{sectionId}}`);
      if (activeNav) activeNav.classList.add('active');

      const rawMarkdown = DOCS_DATA[sectionId].content;
      const html = marked.parse(rawMarkdown);
      const container = document.getElementById('markdown-container');
      container.innerHTML = html;

      container.querySelectorAll('pre').forEach((pre) => {{
        const code = pre.querySelector('code');
        const lang = code ? (code.className.match(/language-([\\w-]+)/) || ['','mojo'])[1] : 'code';

        const wrapper = document.createElement('div');
        wrapper.className = 'code-container';

        const header = document.createElement('div');
        header.className = 'code-header';
        header.innerHTML = `<span>${{lang.toUpperCase()}}</span><button class="copy-btn" onclick="copyCode(this)">Copy</button>`;

        pre.parentNode.insertBefore(wrapper, pre);
        wrapper.appendChild(header);
        wrapper.appendChild(pre);
      }});

      buildTOC(container);
      window.scrollTo({{ top: 0, behavior: 'instant' }});
    }}

    function buildTOC(container) {{
      const tocList = document.getElementById('toc-list');
      tocList.innerHTML = '';

      const headings = container.querySelectorAll('h2, h3');
      headings.forEach((h, idx) => {{
        if (!h.id) {{
          h.id = 'heading-' + idx;
        }}
        const li = document.createElement('li');
        const a = document.createElement('a');
        a.className = 'toc-link' + (h.tagName === 'H3' ? ' indent' : '');
        a.textContent = h.textContent;
        a.href = '#' + h.id;
        a.onclick = (e) => {{
          e.preventDefault();
          h.scrollIntoView({{ behavior: 'smooth' }});
        }};
        li.appendChild(a);
        tocList.appendChild(li);
      }});
    }}

    function copyCode(btn) {{
      const code = btn.closest('.code-container').querySelector('code').innerText;
      navigator.clipboard.writeText(code).then(() => {{
        const originalText = btn.textContent;
        btn.textContent = 'Copied!';
        btn.style.background = 'var(--emerald)';
        btn.style.color = '#000';
        setTimeout(() => {{
          btn.textContent = originalText;
          btn.style.background = '';
          btn.style.color = '';
        }}, 2000);
      }});
    }}

    function openSearch() {{
      const modal = document.getElementById('search-modal');
      modal.classList.add('open');
      const input = document.getElementById('modal-search-input');
      input.value = '';
      input.focus();
      handleSearch('');
    }}

    function closeSearch() {{
      document.getElementById('search-modal').classList.remove('open');
    }}

    function closeSearchOnOverlay(e) {{
      if (e.target.id === 'search-modal') closeSearch();
    }}

    function handleSearch(query) {{
      const resultsContainer = document.getElementById('search-results');
      query = query.trim().toLowerCase();
      if (!query) {{
        resultsContainer.innerHTML = '<div style="padding: 24px; text-align: center; color: var(--text-sub); font-size: 13px;">Type a query to search documentation...</div>';
        return;
      }}

      const matches = [];
      Object.keys(DOCS_DATA).forEach(secId => {{
        const item = DOCS_DATA[secId];
        const lines = item.content.split('\\n');
        lines.forEach(line => {{
          if (line.toLowerCase().includes(query)) {{
            matches.push({{
              secId,
              title: item.title,
              snippet: line.replace(/[#*`]/g, '').trim()
            }});
          }}
        }});
      }});

      if (matches.length === 0) {{
        resultsContainer.innerHTML = '<div style="padding: 24px; text-align: center; color: var(--text-sub); font-size: 13px;">No results found.</div>';
        return;
      }}

      resultsContainer.innerHTML = matches.slice(0, 10).map((m, idx) => `
        <div class="search-item" onclick="navigate('${{m.secId}}'); closeSearch();">
          <div class="search-item-title">${{m.title}}</div>
          <div class="search-item-snippet">${{m.snippet}}</div>
        </div>
      `).join('');
    }}

    window.addEventListener('keydown', (e) => {{
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {{
        e.preventDefault();
        openSearch();
      }}
      if (e.key === 'Escape') {{
        closeSearch();
      }}
    }});

    buildSidebar();
    const initialSection = window.location.hash.replace('#', '') || 'overview';
    navigate(initialSection);
  </script>
</body>
</html>
"""


def main():
    print("1/2 Running `mojo doc` to extract docstrings...")
    try:
        doc_json = run_mojo_doc()
    except subprocess.CalledProcessError as e:
        print(f"Error running mojo doc: {e.stderr}", file=sys.stderr)
        sys.exit(1)

    print(f"    Writing auto-generated reference to {API_MD_FILE}...")
    api_md = generate_markdown(doc_json)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    API_MD_FILE.write_text(api_md, encoding="utf-8")

    print("2/2 Bundling interactive HTML portal...")
    docs_data = load_docs_data()
    html_content = generate_html(docs_data)
    HTML_OUTPUT.write_text(html_content, encoding="utf-8")
    print(f"    HTML documentation portal generated at: {HTML_OUTPUT}")


if __name__ == "__main__":
    main()
