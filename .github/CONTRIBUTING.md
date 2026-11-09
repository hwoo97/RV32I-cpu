# 팀 협업 안내 — RV32I CPU 설계 및 FPGA 구현

## 1. 처음 한 번
1. 초대 메일(또는 GitHub 알림)에서 **Accept invitation**
2. 코드 받기
   ```bash
   git clone (저장소를 만들면 주소 기록)
   git config user.name "이름"
   git config user.email "GitHub에 등록한 이메일"
   ```
3. 먼저 읽을 문서: [README](../README.md) → [개요서](../01_planning/overview.md) → [진행 프로세스](../PROCESS.md)

## 2. 작업 흐름
```bash
git switch main && git pull                  # 최신 받기
git switch -c feat/<영역>-<내용>               # 기능 브랜치
git add <파일> && git commit -m "[영역] 내용"
git push -u origin feat/<영역>-<내용>
```
- GitHub에서 **Pull Request** → 팀원 1명 확인 → main에 병합 (팀 합의로 main 직접 작업을 택하면: 작업 전·push 전 `git pull --rebase`, 작게 자주 커밋, 맡은 폴더만 수정, force push 금지)
- 병합 전: 테스트 통과, 관련 기록(test.md·설계 문서) 갱신

## 3. 이름 규칙
| 종류 | 형식 |
|------|------|
| 기능 / 수정 / 문서 브랜치 | `feat/…` / `fix/…` / `docs/…` |
| 커밋 메시지 | `[폴더 또는 모듈] 내용` |

## 4. 올리지 않는 것
- 시험 사진·대용량 데이터·빌드 결과 (`.gitignore`)
- 개인정보, 비밀번호·토큰, 저작물 원문 — **Public 저장소** 주의

## 5. 장치(서버·보드)
- 장치에서는 코드를 수정하지 않고 받기만(`git pull`) 한다. 수정은 PC에서 커밋·push 후 장치에서 pull.
