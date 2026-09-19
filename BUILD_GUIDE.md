# QT 뷰어 Flutter APK 빌드 가이드

이 문서는 `qt_viewer` 프로젝트(Flutter) 소스로부터 Android APK를 빌드하는 전체 과정을 설명합니다.
Windows 환경 기준이며, 명령어는 Git Bash 또는 PowerShell에서 실행할 수 있습니다.

---

## 1. 프로젝트 구조

```
C:\Temp\workspace\Qt\
├── qt_viewer\                  ← Flutter 프로젝트 루트
│   ├── lib\main.dart           ← 앱 전체 코드 (단일 파일)
│   ├── android\                ← Android 플랫폼 설정 (매니페스트, 아이콘, gradle)
│   │   └── app\src\main\
│   │       ├── AndroidManifest.xml
│   │       └── res\mipmap-*\   ← QT 아이콘 (5종 해상도)
│   ├── web\                    ← 웹 빌드용 파일
│   ├── pubspec.yaml            ← 패키지명/버전/의존성 정의
│   └── build-apk.sh            ← 빌드용 배치 스크립트
├── QT뷰어-flutter-1.0.3.apk    ← 최종 산출물 예시
└── BUILD_GUIDE.md              ← 이 문서
```

앱 핵심 동작 (`lib/main.dart`):

- URL `https://qtland.com/data/meditation/{A|B}{yyyyMMdd}.jpg`에서 이미지 다운로드
- 이미지를 가울데 기준 좌/우 2페이지로 분할 표시 (PageView)
- 핀치 줌 + 상단 `− / +` 버튼 줌 (1.0x ~ 16x), 확대 시 드래그로 이동
- A/B 선택, 날짜 선택/이전날/다음날, 실행 시 오늘 날짜 + A 자동 표시
- 오프라인 시 마지막으로 본 이미지 표시 (shared_preferences에 base64 저장)

---

## 2. 빌드에 필요한 것 (사전 준비)

| 구성요소 | 버전 | 이 프로젝트의 경로/비고 |
|---|---|---|
| Flutter SDK | 3.47.x stable | `C:\Utils\flutter` |
| Dart | Flutter에 내장 | `C:\Utils\flutter\bin\dart` |
| Android SDK | API 34 이상 | `C:\Users\jy030\AppData\Local\Android\Sdk` |
| Android NDK | flutter.ndkVersion에 맞는 버전 | SDK에 포함된 것 사용 |
| JDK | 17 이상 권장 (Gradle용) | `C:\Program Files\Android\Android Studio\jbr` 또는 `C:\Program Files\Java\jdk-11` |
| Git | 임의 | Flutter가 난부적으로 사용 |

### 2.1 Flutter SDK 확인

```bash
flutter --version
# Flutter 3.47.4 • channel stable • Dart 3.13.3
```

Flutter가 PATH에 없으면 매번 아래처럼 PATH를 지정하거나 시스템 환경변수에 추가합니다.

```bash
export PATH="/c/Utils/flutter/bin:$PATH"        # Git Bash
# $env:PATH = "C:\Utils\flutter\bin;$env:PATH"  # PowerShell
```

### 2.2 Flutter에 Android SDK 위치 알려주기

```bash
flutter config --android-sdk "C:\Users\jy030\AppData\Local\Android\Sdk"
```

### 2.3 환경 점검

```bash
flutter doctor
```

Android toolchain 항목에 경고(✗)가 있으면 아래 라이선스 동의를 실행합니다.
(단, sdkmanager가 있는 `cmdline-tools`가 설치되어 있어야 합니다.)

```bash
flutter doctor --android-licenses
```

---

## 3. 의존성 설치

프로젝트 폴리더로 이동 후:

```bash
cd C:\Temp\workspace\Qt\qt_viewer
flutter pub get
```

`pubspec.yaml`의 주요 의존성:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0                # 이미지 다운로드
  shared_preferences: ^2.2.0  # 마지막 이미지 저장 (Android/Web 공용)
```

### 3.1 코드 검증 (선택)

```bash
flutter analyze        # 정적 분석 — "No issues found!" 가 나와야 함
```

---

## 4. APK 빌드

### 4.1 디버그 APK (빠른 테스트용)

```bash
flutter build apk --debug
# 산출물: build\app\outputs\flutter-apk\app-debug.apk
```

디버그 APK는 `android/app/src/debug/AndroidManifest.xml`에 `INTERNET` 권한이 자동 포함됩니다.

### 4.2 릴리즈 APK (배포용)

```bash
flutter build apk --release
# 산출물: build\app\outputs\flutter-apk\app-release.apk
```

릴리즈 APK는 기본적으로 모든 ABI(arm64-v8a, armeabi-v7a, x86_64)를 포함하며
이 프로젝트 기준 약 **50MB**입니다.

### 4.3 ABI별 분할 APK (용량 줄이기, 선택)

```bash
flutter build apk --release --split-per-abi
# app-arm64-v8a-release.apk  (요즘 폰 대부분 — 약 20MB)
# app-armeabi-v7a-release.apk
# app-x86_64-release.apk     (에뮬레이터용)
```

### 4.4 버전 올리기

`pubspec.yaml`에서:

```yaml
version: 1.0.3+3   # 형식: 버전이름+빌드번호
```

---

## 5. 웹 빌드 (선택)

동일한 코드로 웹 버전도 만들 수 있습니다.

```bash
flutter build web --release
# 산출물: build\web\ (index.html이 시작점)
```

`build\web` 폴리더 전체를 임의의 정적 웹서버에 올리면 됩니다.
※ 웹에서는 이미지를 바이트로 받아야 하므로 qtland.com 서버의 CORS 헤더가 허용되어야 합니다. Android 앱은 이 제약이 없습니다.

로컬 테스트:

```bash
cd build\web
python -m http.server 8000
# 브라우저에서 http://localhost:8000
```

---

## 6. 이 프로젝트에서 실제 발생한 문제와 해결 (중요)

### 6.1 릴리즈 APK에서 "표시할 이미지가 없습니다"만 뜨는 현상

**원인**: Flutter 기본 템플릿은 `INTERNET` 권한을 debug 빌드 전용 매니페스트에만 넣습니다.
릴리즈 빌드에는 권한이 없어 앱이 인터넷을 전혀 사용할 수 없습니다.

**해결**: `android/app/src/main/AndroidManifest.xml`의 `<manifest>` 바로 아래에 추가:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

검증 방법 (빌드 후):

```bash
# aapt로 APK 권한 확인
"%LOCALAPPDATA%\Android\Sdk\build-tools\34.0.0\aapt.exe" dump permissions build\app\outputs\flutter-apk\app-release.apk
# uses-permission: name='android.permission.INTERNET'  ← 이 줄이 있어야 함
```

### 6.2 이미지 비율이 세로로 늘어나는 현상

**원인**: `Align(widthFactor: 0.5)` 방식은 특정 상황에서 잘못된 크기로 레이아웃됩니다.

**해결**: 전체 이미지를 원본 비율(2w : h)로 그린 뒤 `ClipRect` + `OverflowBox`로
한쪽 반만 보여주는 방식 사용 (`lib/main.dart`의 `_page()` 참조).
너비와 높이에 항상 같은 배율(`fit * _zoom`)을 곱해 비율을 수학적으로 보장합니다.

### 6.3 확대 후 이미지 이동(드래그)이 안 되는 현상

**원인**: InteractiveViewer 안의 `Center` 위젯이 항상 화면 크기만 한 영역을 차지해
InteractiveViewer가 이동할 공간이 없다고 판단합니다.

**해결**: Center를 제거하고 실제 크기(w×h)의 SizedBox를 InteractiveViewer의 직접 자식으로 사용.

### 6.4 페이지 스와이프와 이미지 드래그 충돌

**해결**: 확대 상태(`_zoom > 1` 또는 핀치 확대 중)일 때만 PageView의 스크롤을 막습니다.

```dart
physics: _isZoomed
    ? const NeverScrollableScrollPhysics()
    : const BouncingScrollPhysics(),
```

페이지 전환은 하단 페이지 점(도트) 탭으로도 가능하게 했습니다.

### 6.5 SDK 플랫폼 폴리더명이 비표준인 경우

이 PC의 SDK에는 `platforms\android-37.0`처럼 이름이 비표준인 폴리더가 있어
Qt(AGP 7.4.1) 빌드에서 문제가 됐던 적이 있습니다. Flutter(AGP 8.x)는 정상 동작했지만,
필요하면 `android/app/build.gradle.kts`에서 플랫폼을 고정합니다.

```kotlin
android {
    compileSdk = 36   // flutter.compileSdkVersion 대신 고정
}
```

### 6.6 JDK 버전

Gradle 실행에 쓰이는 JDK가 너무 새 버전(예: JDK 25)이거나 너무 오래되면 Gradle이
실행되지 않을 수 있습니다. 안드로이드 스튜디오 내장 JBR이나 JDK 17 사용을 권장합니다.
JDK 변경은 `JAVA_HOME` 환경변수로 지정합니다.

```bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
```

---

## 7. 아이콘 변경 방법

현재 아이콘은 PIL(Python)로 생성한 "QT" 텍스트 아이콘입니다.

1. 512×512 PNG(투명 배경, 둥근 사각형 권장)를 준비
2. 아래 해상도로 리사이즈해 각 폴리더에 덮어쓰기

| 폴리더 | 크기 |
|---|---|
| `mipmap-mdpi/ic_launcher.png` | 48×48 |
| `mipmap-hdpi/ic_launcher.png` | 72×72 |
| `mipmap-xhdpi/ic_launcher.png` | 96×96 |
| `mipmap-xxhdpi/ic_launcher.png` | 144×144 |
| `mipmap-xxxhdpi/ic_launcher.png` | 192×192 |

3. 웹 아이콘: `web/icons/Icon-192.png`, `Icon-512.png`, `web/favicon.png`
4. 앱 이름 변경: `AndroidManifest.xml`의 `android:label`
5. 재빌드

---

## 8. 한 번에 실행하는 빌드 스크립트

프로젝트 루트의 `build-apk.sh` 내용:

```bash
#!/bin/bash
export PATH="/c/Utils/flutter/bin:$PATH"
export ANDROID_HOME="C:/Users/jy030/AppData/Local/Android/Sdk"
flutter build apk --release
flutter build web --release
```

실행:

```bash
bash build-apk.sh
```

> **팁**: 첫 빌드는 Gradle과 의존성 다운로드로 10~20분 걸릴 수 있습니다.
> 이후 빌드는 몇 분 내외입니다. 빌드 산출물은 `build/` 폴리더에 누적되므로
> `flutter clean`으로 초기화할 수 있습니다.

---

## 9. 빌드 후 확인 체크리스트

- [ ] `flutter analyze`에서 오류 없음
- [ ] 릴리즈 APK에 `INTERNET` 권한 포함 (6.1의 aapt 명령)
- [ ] APK ZIP 무결성 (압축 해제 오류 없음)
- [ ] 실제 기기 설치 후: 오늘 날짜 A 이미지 표시, A/B 전환, 날짜 이동, 확대/이동, 오프라인 캐시 동작
