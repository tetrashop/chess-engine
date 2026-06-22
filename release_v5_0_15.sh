#!/usr/bin/env bash
set -e
cd ~/chess-engine

echo ">>> 1. مطمئن شدن از بودن روی main و به‌روز بودن"
git checkout main
git pull origin main || true

echo ">>> 2. حذف تگ v5.0.15 (اگر وجود دارد)"
git tag -d v5.0.15 2>/dev/null || true
git push origin :refs/tags/v5.0.15 2>/dev/null || true

echo ">>> 3. افزایش versionCode و versionName"
sed -i 's/versionCode .*/versionCode 304/' bw-project/build.gradle
sed -i 's/versionName .*/versionName "5.0.15"/' bw-project/build.gradle

echo ">>> 4. تنظیم workflow (upload artifact)"
mkdir -p .github/workflows
cat > .github/workflows/release-apk.yml << 'YML'
name: Build APK and Upload Artifact

on:
  push:
    tags:
      - 'v*'

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
      - name: Upload APK to Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ChessEnginePy-APK-v5.0.15
          path: bw-project/app/build/outputs/apk/debug/*.apk
YML

echo ">>> 5. Commit, push, و تگ"
git add -A
git commit -m "Release v5.0.15 – final stable"
git push origin main
git tag v5.0.15
git push origin v5.0.15

echo ""
echo "✅ تگ v5.0.15 با موفقیت push شد."
echo "📌 حالا مراحل زیر را به ترتیب انجام دهید:"
echo "   1. به تب Actions در گیت‌هاب بروید و منتظر بمانید تا workflow کامل شود (حدود ۲ دقیقه)."
echo "   2. روی آخرین اجرا کلیک کنید و در بخش Artifacts فایل ChessEnginePy-APK-v5.0.15 را دانلود کنید."
echo "   3. فایل ZIP را باز کرده و app-debug.apk را استخراج کنید."
echo "   4. به تب Releases بروید، روی ریلیز v5.0.15 کلیک کنید، سپس Edit release را بزنید."
echo "   5. در پایین صفحه، فایل app-debug.apk را Attach کرده و دکمهٔ Update release را بزنید."
echo "🎉 تبریک! حالا ریلیز شما دارای APK است."
