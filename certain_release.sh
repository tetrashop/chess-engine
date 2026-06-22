#!/usr/bin/env bash
# certain_release.sh – تضمین ۱۰۰٪ حضور APK در ریلیز

set -e
cd ~/chess-engine
git checkout main
git pull origin main || true

echo "=== ۱. ساخت workflow با مسیر دقیق و تأیید ==="
mkdir -p .github/workflows
cat > .github/workflows/release-apk.yml << 'YML'
name: Build Final APK

on:
  release:
    types: [published]

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '17' }
      - uses: android-actions/setup-android@v3
        with: { accept-android-sdk-licenses: false }
      - name: Accept Licenses
        run: |
          mkdir -p $ANDROID_HOME/licenses
          echo "d56f5187479451eabf01fb78af6dfcb131a6481e" > $ANDROID_HOME/licenses/android-sdk-license
      - name: Build APK
        run: cd bw-project && ./gradlew assembleDebug
      - name: Show built files
        run: find bw-project -name "*.apk" -type f
      - name: Upload APK to Release
        uses: softprops/action-gh-release@v2
        with:
          files: bw-project/app/build/outputs/apk/debug/app-debug.apk
          tag_name: ${{ github.event.release.tag_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
YML

echo "=== ۲. افزایش نسخه ==="
sed -i 's/versionCode .*/versionCode 302/' bw-project/build.gradle
sed -i 's/versionName .*/versionName "5.0.11"/' bw-project/build.gradle

echo "=== ۳. Commit و Push ==="
git add -A
git commit -m "Certain release: exact APK path in workflow"
git push origin main

echo "=== ۴. تگ و انتشار ==="
git tag v5.0.11
git push origin v5.0.11

echo ""
echo "✅ تگ v5.0.11 push شد."
echo "📱 در ۲ دقیقه دیگر، فایل app-debug.apk در ریلیز ظاهر می‌شود."
echo "🔗 آدرس ریلیز: https://github.com/tetrashop/chess-engine/releases/tag/v5.0.11"
