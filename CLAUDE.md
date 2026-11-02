# 우리애콘 — 반려동물 스티커 팩

반려동물 사진 3장을 기기 안에서 오려 판 어긋난 리소 2판 스티커 12컷 팩으로 만들고, 카톡 카드의 "우리 애도 만들기" 버튼으로 퍼지는 앱. 서버·유료 API 없음.

- 출처: 아이디어 3(펫 이모티콘 세트)
- 목표: 수익이 아니라 **유저 수**. 성장 루프와 북극성 지표는 `docs/design.md` 참고.
- 개발: Flutter, Android 우선, 혼자(평일 저녁 + 주말, 주 약 15시간).

## 파일
- `docs/design.md` — 설계서(문제 정의·가설·MVP·스토리·스프린트·지표·성장 루프·기술 구조·정책·리스크)
- `docs/style.md` — 확정 그림체와 제작 규칙
- `docs/screens/f3-*.png` — 앱 최종 시안 5장(390×844). 위키미디어 사진 변환본이라 공개 레포에서 제외, 로컬에만 있음
- `docs/screens-source/*.dc.html` — 시안 원본(디자인 캔버스 형식, `/_blob/` 이미지는 캔버스에서만 보임)
- `assets/` — 키 비주얼 SVG
- `docs/s1-issues.md` — S1 이슈 원문(GitHub #1~#6) / `docs/h0-measure.md` — H0 측정 방법·결과
- `docs/decisions/` — 결정 기록(ADR). 0001: 리소는 CPU 먼저, GPU는 실측 400ms 초과 시

## 코드 구조
- `lib/riso/riso.dart` — 리소 2판 변환 CPU 기준 구현(순수 Dart, Flutter 비의존). 그림체 규칙은 여기 한 곳에만
- `lib/segmenter.dart` — ML Kit 주체 분할 래퍼(전경 비트맵만, 워밍업, 전경 5%/95% 판정)
- `lib/imaging.dart` — 디코드/PNG 인코드(EXIF 없음), 내용 기반 시드
- `lib/screens/` — S1 스파이크 화면, H0 측정 화면 / `lib/h0_stats.dart` — H0 판정 계산

## 개발 명령 (프로젝트 폴더에서)
- 검사: `dart format lib test tool` → `flutter analyze` → `flutter test`
- 그림체를 바꿨으면 골든 갱신: `$env:UPDATE_GOLDENS="1"; flutter test test/riso_test.dart; Remove-Item Env:UPDATE_GOLDENS` (PowerShell) 후 `test/goldens/riso_disk.png` 눈으로 확인
- 폰 없이 변환 확인: `dart run tool/riso_cli.dart <누끼 PNG> <출력 폴더>`
- 속도: `dart compile exe tool/riso_bench.dart -o riso_bench` → `./riso_bench <누끼 PNG>`
- CI(GitHub Actions): PR·main 푸시마다 포맷·분석·테스트 + arm64 릴리스 APK 아티팩트(14일 보관). 업로드 키 없으면 디버그 키 서명(내 폰 테스트 전용)
- 릴리스 서명: `android/key.properties`(커밋 금지, .gitignore 처리됨)가 있으면 업로드 키 사용

## 일정
3번째 앱. 2027-04-12 시작 → S1 스파이크(분할 품질) → 6/7~6/20 비공개 테스트(6월 기말과 겹침 주의) → 2027-06-27 출시 목표. 설계서 스프린트 날짜는 이 일정으로 바꾸고, 번들 시즌 팩은 연말 대신 여름 팩.

## 첫 스프린트
S1 스파이크 목표: ML Kit 분할 품질·속도 검증(사진 30장 중 80% OK, 중급기 1.5초) + 리소 셰이더 프로토타입. 끝 결과물: 사진 1장 → 리소 스티커 PNG 1장.

## 먼저 확인할 것
시안 강아지 사진은 위키미디어 사진을 변환한 것이라 출시 전 직접 찍은 사진으로 교체. google_mlkit_subject_segmentation은 Android 전용 beta(0.2.1 소스로 옵션·결과 필드 확인함: 전경 비트맵은 네이티브에서 PNG로 넘어옴). 카톡 투명 PNG 유지 여부 미확인(기본 흰 배경 전송, 이슈 #6).

## 작업 규칙 (이 사용자 고정)
- 모든 답변은 한국어. 코드·명령어·고유명사만 원문.
- 결론 먼저, 인사·서론·끝맺음 요약 생략. 위험·되돌릴 수 없는 작업은 충분히 설명.
- 애자일 순서: 문제 정의 → 가설 → MVP/백로그 → 에픽·피처·유저 스토리(S/M/L, 인수 조건) → 2주 스프린트(목표 1~2개, 끝마다 동작하는 결과물) → 지표 측정 → 회고.
- 작업 전 "어제 / 오늘 / 막힌 것" 세 줄 메모. 도구는 GitHub Issues + Projects 하나.
- 코딩은 문제를 푸는 최소 변경, 기존 코드·표준 라이브러리 먼저 재사용, 요청 안 한 추상화 금지. 검증·에러 처리·보안·접근성은 생략 금지.
- API·버전·패키지명은 추측하지 말고 pub.dev·공식 문서로 확인 후 단정.
- 유료 API 0원. 사용자 데이터에 Gemini 무료 등급 쓰지 않음(입출력이 학습에 쓰이고 18세 미만 접근 서비스 금지).
- 앱 아이콘은 흰 바탕에 검정 벡터, 단순·기하학적으로.

## 출시 공통 요건 (2026-10 확인, 출시 직전 재확인)
- Play 개발자 계정 US$25 1회, 한국 개발자 전화번호 인증.
- 신규 개인 계정은 테스터 12명 이상이 14일 연속 비공개 테스트 후 프로덕션 신청 → 15명 모집.
- targetSdk 36(Android 16) 필수, 16KB 페이지 정렬 확인.
- 개인정보처리방침(앱 안 + Play Console), Data safety, IARC 등급 설문.
- 사진은 Photo Picker만(READ_MEDIA_IMAGES 선언 안 함). SMS·연락처 권한 쓰지 않음.
- Firebase Dynamic Links는 2025-08-25 종료 → App Links(assetlinks.json) + Play Install Referrer로 대체.
- 카카오톡 공유 무료 쿼터 일 30,000건, 유료 설정 하지 않음.
