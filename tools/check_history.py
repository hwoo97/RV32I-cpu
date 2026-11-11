"""Checks HISTORY.md and public docs - run before ending a session or uploading.

    python tools/check_history.py            # from the project root

Checks: history numbers are continuous and ordered, every entry has a detail anchor, broken #hN links, file links in the summary,
     number of next-session tasks, relative links in public docs (.md), no links to internal docs from public docs.
Exit code 1 if any problem is found.
"""
import glob
import os
import re
import sys

INTERNAL = ("HISTORY.md", "CLAUDE.md")
# Header that separates the summary from the detailed log in HISTORY.md (Korean text "# sang-se gi-rok")
DETAIL_HEADER = "# 상세 기록"


def check_history(path="HISTORY.md"):
    problems = []
    text = open(path, encoding="utf-8").read()
    if DETAIL_HEADER not in text:
        return [f"{path}: '{DETAIL_HEADER}' separator not found"], {}
    summary = text[:text.index(DETAIL_HEADER)]
    rows = [int(n) for n in re.findall(r"^\| \[(\d+)\]\(#h\1\) \|", summary, re.M)]
    anchors = [int(n) for n in re.findall(r'<a id="h(\d+)"></a>', text)]
    if rows:
        missing = sorted(set(range(1, max(rows) + 1)) - set(rows))
        if missing:
            problems.append(f"missing history numbers: {missing}")
        if rows != sorted(rows):
            problems.append("history entries out of order")
    no_detail = sorted(set(rows) - set(anchors))
    if no_detail:
        problems.append(f"history entries without a detail anchor: {no_detail}")
    dup = sorted({a for a in anchors if anchors.count(a) > 1})
    if dup:
        problems.append(f"duplicate anchors: {dup}")
    broken = sorted({int(n) for n in re.findall(r"\(#h(\d+)\)", text)} - set(anchors))
    if broken:
        problems.append(f"broken #h links: {broken}")
    for target in re.findall(r"\]\(([^)#\s][^)\s]*)\)", summary):
        if not target.startswith("http") and not os.path.exists(target.split("#")[0]):
            problems.append(f"broken file link in summary: {target}")
    todo = len(re.findall(r"^- \[ \] ", summary, re.M))
    done = len(re.findall(r"^- \[x\] ", summary, re.M))
    return problems, {"entries": len(rows), "latest": max(rows) if rows else 0, "tasks (open/done)": f"{todo}/{done}"}


def check_public_docs():
    problems = []
    files = [f for f in glob.glob("**/*.md", recursive=True) + glob.glob(".github/*.md")
             if os.path.basename(f) not in INTERNAL and not f.startswith(("node_modules", ".venv"))]
    for f in files:
        text = open(f, encoding="utf-8").read()
        for target in re.findall(r"\]\(([^)\s]+)\)", text):
            if target.startswith(("http", "#", "mailto")):
                continue
            path = target.split("#")[0]
            if os.path.basename(path) in INTERNAL:
                problems.append(f"{f}: internal doc link in a public doc ({target})")
            elif not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f), path))):
                problems.append(f"{f}: broken link ({target})")
    return problems, len(files)


def main():
    problems, stats = check_history() if os.path.exists("HISTORY.md") else (["HISTORY.md not found"], {})
    doc_problems, n_docs = check_public_docs()
    problems += doc_problems
    print("HISTORY:", ", ".join(f"{k} {v}" for k, v in stats.items()))
    print(f"public docs: {n_docs}")
    if problems:
        print("\n[problems]")
        for p in problems:
            print(" -", p)
        sys.exit(1)
    print("no problems")


if __name__ == "__main__":
    main()
