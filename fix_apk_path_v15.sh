#!/usr/bin/env bash
# fix_apk_path_v15.sh – رفع مشکل مسیر APK و انتشار v15.0.4

set -e
cd ~/chess-engine

echo "⚙️ ۱. اصلاح workflow (استفاده از find + cp)"
cat > .github/workflows/release-apk.yml << 'YML'
name: Build APK
on:
  push:
    tags:
      - 'v*'
permissions:
  contents: write
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '17' }
      - name: Setup Android SDK (manual)
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y -qq wget unzip
          export ANDROID_HOME=$HOME/android-sdk
          mkdir -p $ANDROID_HOME/cmdline-tools
          wget -q https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip
          unzip -q commandlinetools-linux-8512546_latest.zip -d $ANDROID_HOME/cmdline-tools
          mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest
          yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null || true
      - name: Build APK
        run: cd bw-project && ./gradlew assembleDebug
      - name: Copy APK to root (find)
        run: |
          find bw-project -name "*.apk" -type f -exec cp {} ./app.apk \;
          ls -la app.apk   # تأیید وجود
      - name: Upload APK to Release
        uses: softprops/action-gh-release@v2
        with:
          files: app.apk
          tag_name: ${{ github.ref_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Upload APK to Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ChessEnginePy-APK-${{ github.ref_name }}
          path: app.apk
YML

echo "📦 ۲. افزایش نسخه به ۱۵.۰.۴ (versionCode 1504)"
sed -i 's/versionCode .*/versionCode 1504/' bw-project/build.gradle
sed -i 's/versionName .*/versionName "15.0.4"/' bw-project/build.gradle

echo "📦 ۳. Commit، Push و تگ"
git add -A
git commit -m "Fix APK path with find, v15.0.4"
git push origin main

git tag -d v15.0.4 2>/dev/null || true
git push origin :refs/tags/v15.0.4 2>/dev/null || true
git tag v15.0.4
git push origin v15.0.4

echo ""
echo "✅ تگ v15.0.4 push شد."
echo "📱 پس از ۲ دقیقه به Actions بروید و APK را از Artifacts دانلود کنید:"
echo "   https://github.com/tetrashop/chess-engine/actions"
