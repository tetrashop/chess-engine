#!/usr/bin/env bash
# restore_workflow_and_release.sh – بازسازی فایل‌های ضروری و انتشار v15.0.1

set -e
cd ~/chess-engine

echo "⚙️ ۱. ساخت پوشه‌های ضروری"
mkdir -p .github/workflows
mkdir -p bw-project/gradle/wrapper

echo "⚙️ ۲. ایجاد فایل workflow (Release + Artifact)"
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
      - uses: android-actions/setup-android@v3
        with: { accept-android-sdk-licenses: false }
      - name: Accept Licenses
        run: |
          mkdir -p $ANDROID_HOME/licenses
          echo "d56f5187479451eabf01fb78af6dfcb131a6481e" > $ANDROID_HOME/licenses/android-sdk-license
      - name: Build APK
        run: cd bw-project && ./gradlew assembleDebug
      - name: Copy APK to root
        run: |
          find bw-project -name "*.apk" -type f -exec cp {} ./app.apk \;
          ls -la app.apk
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

echo "⚙️ ۳. ایجاد Gradle Wrapper"
cat > bw-project/gradlew << 'GRADLEW'
#!/bin/bash
PRG="$0"
while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then PRG="$link"; else PRG=`dirname "$PRG"`/"$link"; fi
done
APP_HOME=`dirname "$PRG"`
if [ ! -f "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" ]; then
  echo "Downloading Gradle wrapper..."
  mkdir -p "$APP_HOME/gradle/wrapper"
  curl -L -o "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" \
    https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradle/wrapper/gradle-wrapper.jar
fi
java -cp "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain "$@"
GRADLEW
chmod +x bw-project/gradlew

cat > bw-project/gradle/wrapper/gradle-wrapper.properties << 'PROPS'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
PROPS

echo "📦 ۴. افزایش نسخه به ۱۵.۰.۱ (versionCode 1501)"
sed -i 's/versionCode .*/versionCode 1501/' bw-project/build.gradle
sed -i 's/versionName .*/versionName "15.0.1"/' bw-project/build.gradle

echo "📦 ۵. Commit، Push و تگ"
git add -A
git commit -m "Restore workflow and gradlew, v15.0.1"
git push origin main
git tag v15.0.1
git push origin v15.0.1

echo ""
echo "✅ تگ v15.0.1 با موفقیت push شد."
echo "📱 پس از ۲ دقیقه به Actions بروید و APK را از Artifacts دانلود کنید:"
echo "   https://github.com/tetrashop/chess-engine/actions"
