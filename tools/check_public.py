"""공개 저장소에 올리기 전에 커밋될 파일을 점검한다.

    python tools/check_public.py          # 커밋 대상(추적 + 새 파일) 전체
    python tools/check_public.py --staged # git add 한 파일만

점검 항목
- PDK·툴 원본 파일 확장자 (.lib .lef .def .gds .spef .sdf 넷리스트 등)
- PDK·툴 설치 경로, 서버 정보, 개인 정보
- 툴이 만든 파일의 저작권 머리말 (Cadence 등)
- 큰 파일 (5 MB 초과)
문제가 하나라도 있으면 종료 코드 1.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_BYTES = 5 * 1024 * 1024

BLOCKED_EXT = {
    ".lib", ".lef", ".tlef", ".tf", ".db", ".cdl", ".qrc", ".captbl", ".techfile",
    ".def", ".gds", ".gds2", ".gdsii", ".oas", ".spef", ".sdf", ".vg", ".rpt",
    ".enc", ".pdf",
}
BLOCKED_NAME = [re.compile(r"_netlist\.v$"), re.compile(r"(^|/)fv/")]

PATTERNS = [
    ("PDK·툴 설치 경로", re.compile(r"/tools/cadence|/[\w.\-/]*gpdk045/[\w.\-/]+", re.I)),
    ("툴 저작권 머리말", re.compile(r"Cadence Design Systems|Copyright .{0,40}Cadence|Synopsys, Inc\.", re.I)),
    ("PDK 라이브러리 내용", re.compile(r"^\s*library\s*\(|^\s*MACRO\s+\w+|^\s*cell\s*\(\s*\w+\s*\)\s*\{", re.M)),
    ("서버 정보", re.compile(r"kopo-seongnam|hah015", re.I)),
    ("개인 정보", re.compile(r"gusdn5883|[\w.+-]+@(?:naver|gmail|daum)\.(?:com|net)", re.I)),
    ("비밀 정보", re.compile(r"ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|password\s*[:=]\s*\S+", re.I)),
]

SELF = os.path.relpath(os.path.abspath(__file__), ROOT).replace(os.sep, "/")


def candidate_files(staged):
    if staged:
        cmd = ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"]
    else:
        cmd = ["git", "ls-files", "--cached", "--others", "--exclude-standard"]
    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [line for line in out.splitlines() if line]


def check_file(path):
    problems = []
    full = os.path.join(ROOT, path)
    ext = os.path.splitext(path)[1].lower()
    if ext in BLOCKED_EXT or any(p.search(path) for p in BLOCKED_NAME):
        problems.append("올리면 안 되는 파일 종류")
    if not os.path.isfile(full):
        return problems
    if os.path.getsize(full) > MAX_BYTES:
        problems.append("5 MB 초과 파일")
    if path == SELF:
        return problems
    try:
        text = open(full, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        return problems
    for name, pattern in PATTERNS:
        match = pattern.search(text)
        if match:
            line = text.count("\n", 0, match.start()) + 1
            problems.append(f"{name} ({line}행: {match.group(0)[:40]!r})")
    return problems


def main():
    staged = "--staged" in sys.argv
    files = candidate_files(staged)
    failed = 0
    for path in files:
        for problem in check_file(path):
            print(f"FAIL: {path} — {problem}")
            failed += 1
    if failed:
        sys.exit(f"점검 실패: {failed}건 (파일 {len(files)}개 중)")
    print(f"PASS: 파일 {len(files)}개 점검, 문제 없음")


if __name__ == "__main__":
    main()
