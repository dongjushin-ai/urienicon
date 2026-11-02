# S1 실기기 확인 스크립트 (Windows PowerShell 5 호환)
#
#   cd C:\Users\ben10\Desktop\Projects\urienicon-kit\urienicon
#   powershell -ExecutionPolicy Bypass -File scripts\s1-device.ps1
#
# 하는 일: 폰 연결 확인 → 기기 정보 기록 → 릴리스 APK 빌드·설치 → 앱 실행 →
#          (폰에서 직접 테스트) → 화면·로그 수집. 결과는 s1-results\ 에 저장.
# 하지 않는 일: 폰의 사진·데이터를 읽거나 지우지 않음. 앱 외 설정 변경 없음.

# PS5는 네이티브 명령의 stderr를 오류로 바꿔 중단시키므로 Continue + 종료 코드로 직접 확인
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$out = Join-Path $root 's1-results'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$pkg = 'com.docky.urienicon'

function Step($msg) { Write-Host ''; Write-Host "== $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

# adb 찾기: PATH → Android SDK 기본 위치
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
  $cand = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
  if (Test-Path $cand) { $adb = $cand }
}
if (-not $adb) { Fail 'adb를 찾지 못했어요. Android Studio에서 SDK Platform-Tools를 설치해 주세요.' }

Step '1/6 폰 연결 확인'
$lines = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' }
$ready = @($lines | Where-Object { $_ -match '\tdevice$' })
if ($ready.Count -eq 0) {
  if ($lines -match 'unauthorized') { Fail '폰 화면의 "USB 디버깅 허용"을 눌러 주세요. 그다음 다시 실행.' }
  Fail '연결된 폰이 없어요. USB 디버깅을 켜고 데이터 케이블로 연결한 뒤 다시 실행해 주세요.'
}
if ($ready.Count -gt 1) { Fail '폰이 2대 이상 연결돼 있어요. 측정할 폰 1대만 연결해 주세요.' }
$serial = ($ready[0] -split '\t')[0]
function Adb { & $adb -s $serial @args }
function Prop($name) { "$(Adb shell getprop $name)".Trim() }
# PS5의 > 리디렉션은 바이너리를 UTF-16으로 깨뜨리므로 폰에 저장 후 pull
function Shot($name) {
  $tmp = "/data/local/tmp/urienicon_$name"
  Adb shell screencap -p $tmp | Out-Null
  Adb pull $tmp (Join-Path $out $name) | Out-Null
  Adb shell rm $tmp | Out-Null
}

Step '2/6 기기 정보 기록'
$model = Prop ro.product.model
$android = Prop ro.build.version.release
$sdk = Prop ro.build.version.sdk
$soc = Prop ro.soc.model
$memKb = ((Adb shell cat /proc/meminfo | Select-String 'MemTotal') -replace '\D', '')
$memGb = [math]::Round([double]$memKb / 1MB, 1)
$gms = (Adb shell pm list packages com.google.android.gms) -match 'gms'
$info = @(
  "model=$model", "android=$android", "sdk=$sdk", "soc=$soc", "ram_gb=$memGb",
  "play_services=$([bool]$gms)", "date=$(Get-Date -Format s)"
)
$info | Set-Content -Encoding UTF8 (Join-Path $out 'device.txt')
$info | ForEach-Object { Write-Host "  $_" }

Step '3/6 릴리스 APK 빌드 (처음엔 몇 분 걸려요)'
flutter pub get
if ($LASTEXITCODE -ne 0) { Fail 'flutter pub get 실패' }
flutter build apk --release --target-platform android-arm64
if ($LASTEXITCODE -ne 0) { Fail 'APK 빌드 실패. 위 오류를 Claude에게 붙여 주세요.' }
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'

Step '4/6 설치·실행'
# 이전에 다른 키로 서명된 같은 앱이 있으면 설치가 막힘 → 앱만 지우고 다시 설치(이 앱 데이터만 삭제됨)
$res = Adb install -r $apk 2>&1 | Out-String
if ($res -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
  Write-Host '  서명이 달라 기존 우리애콘을 지우고 다시 설치합니다(이 앱 데이터만 삭제).'
  Adb uninstall $pkg | Out-Null
  $res = Adb install $apk 2>&1 | Out-String
}
if ($res -notmatch 'Success') { Fail "설치 실패: $res" }
Adb logcat -c
Adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 4
Shot '01-home.png'

Step '5/6 폰에서 직접 테스트해 주세요'
Write-Host '  ① "사진 1장 → 리소 스티커" → 반려동물 사진 1장 → 결과와 시간표가 보이면 그대로 두기'
Write-Host '     (권한 팝업이 떴는지 기억해 주세요. 정상은 0번)'
Write-Host '  ② 이 창으로 돌아와 Enter → 그 화면을 캡처합니다'
Read-Host '  준비되면 Enter' | Out-Null
Shot '02-spike.png'
Write-Host '  ③ "갤러리에 저장" → 갤러리 앱 "우리애콘" 앨범에 2장이 있는지 확인 → ④ 뒤로 → "H0 분할 측정" → 기기 이름 입력 → 사진 여러 장 → 끝까지 OK/NG 판정'
Write-Host '  ⑤ 요약 카드가 보이게 스크롤을 맨 위로 올리고, 오른쪽 위 복사 버튼을 누른 뒤 이 창에서 Enter'
Read-Host '  준비되면 Enter' | Out-Null
Shot '03-h0.png'

Step '6/6 로그 수집'
# 이 앱 프로세스 로그 + 크래시 버퍼만 저장(다른 앱 로그는 저장하지 않음)
$appPid = "$(Adb shell pidof $pkg)".Trim()
if ($appPid) {
  Adb logcat -d --pid=$appPid | Set-Content -Encoding UTF8 (Join-Path $out 'logcat-app.txt')
}
Adb logcat -d -b crash | Set-Content -Encoding UTF8 (Join-Path $out 'logcat-crash.txt')

Write-Host ''
Write-Host "완료. 결과: $out" -ForegroundColor Green
Write-Host '  Claude에게 "측정 끝났어"라고 말하고, 복사한 H0 CSV도 채팅에 붙여 주세요.'
