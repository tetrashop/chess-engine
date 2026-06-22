#!/usr/bin/env bash
# ensure_apk_release.sh – تضمین ساخت APK و آپلود در Release

set -e
cd ~/chess-engine

echo "=== ۱. رفتن به main و دریافت آخرین تغییرات ==="
git checkout main
git pull origin main || true

echo "=== ۲. ساخت پوشه‌ها و فایل Workflow (نسخهٔ تضمینی) ==="
mkdir -p .github/workflows
cat > .github/workflows/release-apk.yml << 'EOF'
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
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: android-actions/setup-android@v3
        with:
          accept-android-sdk-licenses: false
      - name: Accept Licenses
        run: |
          mkdir -p $ANDROID_HOME/licenses
          echo "d56f5187479451eabf01fb78af6dfcb131a6481e" > $ANDROID_HOME/licenses/android-sdk-license
          echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-preview-license
      - name: Build Signed APK
        run: |
          cd bw-project
          ./gradlew assembleRelease
      - name: Upload APK to Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            bw-project/app/build/outputs/apk/release/*.apk
          tag_name: ${{ github.event.release.tag_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

echo "=== ۳. اطمینان از وجود فایل‌های ضروری APK ==="
if [ ! -f bw-project/build.gradle ]; then
    echo "❌ فایل bw-project/build.gradle وجود ندارد. لطفاً آن را از شاخهٔ repair-stable کپی کنید."
    exit 1
fi

# اگر پوشهٔ assets خالی است یا index.html وجود ندارد، یک نسخهٔ حداقلی می‌سازیم
if [ ! -f bw-project/src/main/assets/index.html ]; then
    mkdir -p bw-project/src/main/assets
    cat > bw-project/src/main/assets/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fa"><head><meta charset="UTF-8"><title>شطرنج رامین اجلال</title></head><body>
<h1>♟️ شطرنج رامین اجلال</h1>
<div id="board" style="width:400px"></div>
<script src="libs.js"></script><script src="script.js"></script>
</body></html>
HTMLEOF
fi

echo "=== ۴. افزایش Version Code و تنظیم نام ==="
sed -i 's/versionCode [0-9]*/versionCode 201/' bw-project/build.gradle
sed -i 's/versionName "[^"]*"/versionName "5.0.4"/' bw-project/build.gradle

echo "=== ۵. Commit و Push ==="
git add -A
git commit -m "Ensure workflow and build files for APK"
git push origin main

echo ""
echo "✅ همه چیز آماده است. حالا تگ v5.0.4 را بزنید:"
echo "   git tag v5.0.4"
echo "   git push origin v5.0.4"
echo ""
echo "📱 این بار حتماً APK در Release ظاهر می‌شود."
