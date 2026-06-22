#!/usr/bin/env bash
# final_working_release.sh – تضمین آپلود APK در Release

set -e
cd ~/chess-engine

echo "=== ۱. اصلاح workflow (استفاده از find + assembleDebug) ==="
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
      - name: Build Debug APK
        run: |
          cd bw-project
          ./gradlew assembleDebug
      - name: Upload all APKs to Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            $(find bw-project -name "*.apk" -type f)
          tag_name: ${{ github.event.release.tag_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

echo "=== ۲. افزایش versionCode و نام نسخه ==="
sed -i 's/versionCode [0-9]*/versionCode 204/' bw-project/build.gradle
sed -i 's/versionName "[^"]*"/versionName "5.0.8"/' bw-project/build.gradle

echo "=== ۳. Commit و Push ==="
git add -A
git commit -m "Fix APK upload: use find + assembleDebug"
git push origin main

echo ""
echo "✅ همه چیز آماده است. حالا تگ جدید را بزنید:"
echo "   git tag v5.0.8"
echo "   git push origin v5.0.8"
echo ""
echo "📱 این بار فایل APK (app-debug.apk) در Release ظاهر خواهد شد."
