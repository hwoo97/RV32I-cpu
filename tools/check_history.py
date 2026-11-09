"""HISTORY.md·공개 문서 점검 — 세션 종료·업로드 전에 실행.

    python tools/check_history.py            # 프로젝트 루트에서

확인: 작업 이력 번호 연속·순서, 이력마다 상세 기록 앵커, 깨진 #hN 링크, 요약의 파일 링크,
     다음 세션 할 일 개수, 공개 문서(.md)의 상대 링크, 공개 문서에 내부 문서 링크가 없는지.
문제가 있으면 종료 코드 1.
"""
import glob
import os
import re
import sys

INTERNAL = ("HISTORY.md", "CLAUDE.md")


def check_history(path="HISTORY.md"):
    problems = []
    text = open(path, encoding="utf-8").read()
    if "# 상세 기록" not in text:
        return [f"{path}: '# 상세 기록' 구분선 없음"], {}
    summary = text[:text.index("# 상세 기록")]
    rows = [int(n) for n in re.findall(r"^\| \[(\d+)\]\(#h\1\) \|", summary, re.M)]
    anchors = [int(n) for n in re.findall(r'<a id="h(\d+)"></a>', text)]
    if rows:
        missing = sorted(set(range(1, max(rows) + 1)) - set(rows))
        if missing:
            problems.append(f"작업 이력 번호 빠짐: {missing}")
        if rows != sorted(rows):
            problems.append("작업 이력 순서가 뒤섞임")
    no_detail = sorted(set(rows) - set(anchors))
    if no_detail:
        problems.append(f"상세 기록(앵커) 없는 이력: {no_detail}")
    dup = sorted({a for a in anchors if anchors.count(a) > 1})
    if dup:
        problems.append(f"앵커 중복: {dup}")
    broken = sorted({int(n) for n in re.findall(r"\(#h(\d+)\)", text)} - set(anchors))
    if broken:
        problems.append(f"깨진 #h 링크: {broken}")
    for target in re.findall(r"\]\(([^)#\s][^)\s]*)\)", summary):
        if not target.startswith("http") and not os.path.exists(target.split("#")[0]):
            problems.append(f"요약의 깨진 파일 링크: {target}")
    todo = len(re.findall(r"^- \[ \] ", summary, re.M))
    done = len(re.findall(r"^- \[x\] ", summary, re.M))
    return problems, {"이력": len(rows), "최근": max(rows) if rows else 0, "할 일(남음/끝)": f"{todo}/{done}"}


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
                problems.append(f"{f}: 공개 문서에 내부 문서 링크 ({target})")
            elif not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f), path))):
                problems.append(f"{f}: 깨진 링크 ({target})")
    return problems, len(files)


def main():
    problems, stats = check_history() if os.path.exists("HISTORY.md") else (["HISTORY.md 없음"], {})
    doc_problems, n_docs = check_public_docs()
    problems += doc_problems
    print("HISTORY:", ", ".join(f"{k} {v}" for k, v in stats.items()))
    print(f"공개 문서: {n_docs}개")
    if problems:
        print("\n[문제]")
        for p in problems:
            print(" -", p)
        sys.exit(1)
    print("문제 없음")


if __name__ == "__main__":
    main()
