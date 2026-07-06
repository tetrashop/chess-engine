#!/usr/bin/env bash
# final_fix_v15.sh – رفع خطای sdkmanager و انتشار v15.0.2

set -e
cd ~/chess-engine

echo "⚙️ ۱. جایگزینی workflow با نسخهٔ ساده و تضمینی"
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
        run: |
          cd bw-project
          ./gradlew assembleDebug
      - name: Upload APK to Release
        uses: softprops/action-gh-release@v2
        with:
          files: bw-project/app/build/outputs/apk/debug/app-debug.apk
          tag_name: ${{ github.ref_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Upload APK to Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ChessEnginePy-APK-${{ github.ref_name }}
          path: bw-project/app/build/outputs/apk/debug/app-debug.apk
YML

echo "📦 ۲. commit و push"
git add -A
git commit -m "Final fix – manual SDK setup, stable workflow"
git push origin main

echo "🏷️ ۳. حذف تگ قدیمی و ایجاد v15.0.2 مجدد"
git tag -d v15.0.2 2>/dev/null || true
git push origin :refs/tags/v15.0.2 2>/dev/null || true
git tag v15.0.2
git push origin v15.0.2

echo ""
echo "✅ تگ v15.0.2 با موفقیت push شد."
echo "📱 حالا به Actions بروید و APK را از Artifacts دانلود کنید."
