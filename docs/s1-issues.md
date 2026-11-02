# S1 스파이크 이슈 목록 (2027-04-12 ~ 04-25)

스프린트 목표: ① ML Kit 분할 품질·속도 검증(H0) ② 리소 셰이더 프로토타입
끝 결과물: 사진 1장 → 리소 스티커 PNG 1장 갤러리 저장 + 사진 30장·기기 2대 측정표
라벨: `sprint:S1` + 크기(`S`/`M`) + 에픽(`epic:A`/`spike`). 마일스톤 `S1 스파이크`.

| # | 제목 | 크기 | 스토리 |
|---|---|---|---|
| 1 | A1 Photo Picker로 사진 고르기 | S | A1 |
| 2 | A2 ML Kit로 반려동물 오려내기 | M | A2 |
| 3 | H0 분할 측정: 사진 30장 × 기기 2대 | M | H0 |
| 4 | A4 리소 2판 셰이더 프로토타입 | M | A4(초안) |
| 5 | 리소 스티커 PNG 1장 갤러리 저장 | S | B1 일부 |
| 6 | 카톡 투명 PNG 전송 실기기 확인 | S | 확인 항목 |

---

## 1. A1 Photo Picker로 사진 고르기 `S`
보호자로서 사진을 고른다, 권한 걱정 없이 바로 시작하려고.

인수 조건
- [ ] 권한 팝업 0회. `READ_MEDIA_IMAGES` 미선언 유지(병합 매니페스트로 확인)
- [ ] Android 15 이하도 Photo Picker: `ImagePickerAndroid.useAndroidPhotoPicker = true` (`image_picker_android` 직접 의존 추가 필요)
- [ ] S1은 1장, 상한 5장(`limit`)은 Android 13+에서만 보장됨
- [ ] 긴 변 1024px로 줄여 앱 전용 폴더 저장, 512px 미만이면 경고
- [ ] 선택 취소·실패 시 안내 문구, 앱 멈춤 없음

## 2. A2 ML Kit로 반려동물 오려내기 `M`
보호자로서 배경이 지워진 미리보기를 본다, 우리 애만 쓰려고.

확인된 API (`google_mlkit_subject_segmentation` 0.2.1 소스 기준)
- `SubjectSegmenter(options: SubjectSegmenterOptions(enableForegroundBitmap:, enableForegroundConfidenceMask:, enableMultipleSubjects: SubjectResultOptions(enableConfidenceMask:, enableSubjectBitmap:)))` — 세 값 모두 required
- `processImage(InputImage.fromFilePath(path))` → `SubjectSegmentationResult { Uint8List? foregroundBitmap, List<double>? foregroundConfidenceMask, List<Subject> subjects }`
- `foregroundBitmap`은 네이티브에서 **PNG(품질 100)로 인코딩된 바이트**. 알파가 마스크 역할
- `foregroundConfidenceMask`는 픽셀 수만큼 double 리스트가 채널로 넘어옴(1024² ≈ 100만 개) → 기본은 끄고 비트맵 알파 사용, 측정에서 비교만
- 사용 후 `close()` 필수

인수 조건
- [ ] 중급기 1장 ≤ 1.5초(채널 전송·PNG 디코드 포함 측정)
- [ ] 앱 시작 시 더미 추론 1회(첫 추론 지연 제거)
- [ ] 전경 비율 5% 미만·95% 초과면 "다른 사진" 안내
- [ ] 모델 미설치로 결과가 비면 "잠시 후 다시" 안내(manifest `subject_segment` 미리 받기는 뼈대에 반영됨)
- [ ] 처리 중 진행 표시, 오류 시 Crash 없이 안내

## 3. H0 분할 측정: 사진 30장 × 기기 2대 `M`
개발자로서 분할 품질을 수치로 본다, H0를 판정하려고.

- [ ] 직접 찍은 반려동물 사진 30장(강아지·고양이, 검은 털·배경 비슷한 색 각 3장 이상 포함). 시안의 위키미디어 사진은 쓰지 않음
- [ ] 기기 2대(중급기 1, 저사양 RAM 3~4GB 1)에서 장별 `segment ms`·OK/NG 기록 → `docs/h0-measure.md` 표
- [ ] 판정: OK ≥ 24장(80%), 중급기 중앙값 ≤ 1.5초. 실패 시 다듬기·촬영 가이드 강화로 방향 수정(설계서 S1)

## 4. A4 리소 2판 셰이더 프로토타입 `M`
보호자로서 사진이 2도 인쇄 스티커처럼 바뀌는 걸 본다, 사진과 다른 "작품"을 갖고 싶어서.

> 2026-11-02 변경: CPU 기준 구현(`lib/riso/riso.dart`)이 AOT 89ms(서버), 중급기 예상 300~450ms로 CPU 목표 ≤1초 안.
> GPU 셰이더는 **실기기 중급기 중앙값 400ms 초과 시에만** 만든다 → `docs/decisions/0001-riso-cpu-first.md`.

- [x] CPU 기준 구현 + 단위·골든 테스트(재현성, (+6,+5) 어긋남, 테두리 11px, 잉크 빠짐 3~6%, 점선, 잡티 제거)
- [x] 같은 사진은 같은 결과(내용 기반 시드)
- [x] 망점이 확대 없이 보임(셀 6px), 흰 테두리 11px, 블루 윤곽 5px
- [x] style.md 값 vs 설계서 값 비교 렌더: `dart run tool/riso_cli.dart <누끼> <폴더> 7 --design`
  → 설계서 값은 어긋남 (3,−2)이 작아 시그니처가 약하고 블루가 청록에 가까움. **style.md 값 유지**
- [ ] 실기기에서 "리소 변환 (CPU)" 시간 측정(스파이크 화면) → ADR 재검토 기준 400ms
- [ ] (조건부) `shaders/riso.frag` — 위 측정이 400ms 초과일 때만
- 레지스트레이션 마크(구석 2색)는 컷 프레임 요소라 12컷 구성(S2, A6)에서 구현

| 항목 | style.md (확정, 채택) | design.md 10장 |
|---|---|---|
| 판 색 | 핑크 #ff4fa3, 블루 #2f4fb8 | 핑크 #FF48B0, 블루 #0078BF(근사) |
| 판 역할 | 핑크 = 명도 하프톤, 블루 = 엣지 선(Sobel)·윤곽 5px·그림자 망점 | 두 판 모두 회전 망점 |
| 어긋남 | 블루 판 (+6,+5)px | 핑크 판 (3,−2)px + 0.4° |

## 5. 리소 스티커 PNG 1장 갤러리 저장 `S`
보호자로서 만든 스티커를 갤러리에 저장한다, 바로 보내 보려고.

- [ ] `PictureRecorder` → `toImage` → PNG → `gal`로 저장(투명 1장 + 종이색 배경 1장)
- [ ] EXIF 없음 확인
- [ ] Android 10 이하는 `WRITE_EXTERNAL_STORAGE`(maxSdk 29) 요청이 저장 시점에만 뜸(뼈대에 선언됨), 거부 시 안내

## 6. 카톡 투명 PNG 전송 실기기 확인 `S`
개발자로서 투명 PNG가 카톡에서 어떻게 보이는지 안다, 기본 전송 배경을 확정하려고.

- [ ] 5번 투명 PNG를 공유 시트 → 카톡으로 일반 화질·원본 각각 전송, 라이트·다크 채팅방 캡처
- [ ] 결과를 설계서 9장 "카카오톡에 투명 PNG 전송" 행에 기록(현재 미확인, 웹 검색으로도 공식 자료 못 찾음)

---

### 참고: 2026-10-24 pub.dev 재확인
- S1 의존성(뼈대에 추가됨): `image_picker` 1.2.4, `google_mlkit_subject_segmentation` 0.2.1, `gal` 2.3.3
- 설계서와 달라진 것: `kakao_flutter_sdk_share` 2.1.0(설계서 2.0.1), `firebase_analytics` 13.0.1, `firebase_crashlytics` 6.0.1 → S3에서 다시 확인 후 추가
- Flutter 3.47.8 stable 기본값: compileSdk 36, targetSdk 36, minSdk 24(ML Kit 요구와 같음)
