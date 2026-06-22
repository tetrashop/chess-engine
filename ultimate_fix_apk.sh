#!/usr/bin/env bash
set -e
cd ~/chess-engine
git checkout main
git pull origin main || true

# workflow با مسیر دقیق debug (همیشه یکسان)
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
      - name: Upload APK
        uses: softprops/action-gh-release@v2
        with:
          files: bw-project/app/build/outputs/apk/debug/*.apk
          tag_name: ${{ github.event.release.tag_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
YML

# افزایش نسخه
sed -i 's/versionCode .*/versionCode 301/' bw-project/build.gradle
sed -i 's/versionName .*/versionName "5.0.10"/' bw-project/build.gradle

git add -A
git commit -m "Fix APK upload path – use debug directory"
git push origin main
git tag v5.0.10
git push origin v5.0.10
echo "✅ تگ v5.0.10 push شد. APK در ۲ دقیقه در Release حاضر می‌شود."
