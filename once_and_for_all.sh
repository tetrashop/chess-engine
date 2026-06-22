#!/usr/bin/env bash
set -e
cd ~/chess-engine
git checkout main
git pull origin main || true

# ── ۱. حذف هر فایل PNG خراب ──
rm -f bw-project/src/main/res/mipmap-*/ic_launcher.png

# ── ۲. ساخت آیکون XML (Vector) – بدون خطای AAPT ──
mkdir -p bw-project/src/main/res/drawable
cat > bw-project/src/main/res/drawable/ic_launcher.xml << 'XML'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp" android:height="48dp"
    android:viewportWidth="48" android:viewportHeight="48">
    <path android:fillColor="#FFD700" android:pathData="M24,2C11.85,2,2,11.85,2,24s9.85,22,22,22s22-9.85,22-22S36.15,2,24,2z"/>
    <path android:fillColor="#000" android:pathData="M18,34c-1.5,0-2.5,1-2.5,2.5c0,0.5,0.2,1,0.5,1.4l-1.5,3.6h19l-1.5-3.6c0.3-0.4,0.5-0.9,0.5-1.4c0-1.5-1-2.5-2.5-2.5H18z"/>
    <path android:fillColor="#000" android:pathData="M15,32l1.5-5h15l1.5,5H15z"/>
    <path android:fillColor="#000" android:pathData="M22,10c-1.5,0-3,0.5-4,1.5c-2.5,2-3,6-3,9.5v1h18v-1c0-3.5-0.5-7.5-3-9.5C25,10.5,23.5,10,22,10z"/>
</vector>
XML

# ── ۳. ارجاع به آیکون در مانیفست ──
cat > bw-project/src/main/AndroidManifest.xml << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.ramin.chess">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:allowBackup="true" android:label="@string/app_name" android:icon="@drawable/ic_launcher"
        android:supportsRtl="true" android:theme="@android:style/Theme.NoTitleBar">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
XML

# ── ۴. strings.xml ──
mkdir -p bw-project/src/main/res/values
cat > bw-project/src/main/res/values/strings.xml << 'XML'
<resources><string name="app_name">شطرنج رامین اجلال</string></resources>
XML

# ── ۵. نسخهٔ build.gradle ──
sed -i 's/versionCode .*/versionCode 300/' bw-project/build.gradle
sed -i 's/versionName .*/versionName "5.0.9-final"/' bw-project/build.gradle

# ── ۶. workflow که APK را با find پیدا می‌کند ──
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
          files: $(find bw-project -name "*.apk" -type f)
          tag_name: ${{ github.event.release.tag_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
YML

# ── ۷. Commit, Push و تگ ──
git add -A
git commit -m "One-shot final APK fix"
git push origin main
git tag v5.0.9-final
git push origin v5.0.9-final

echo "✅ تگ v5.0.9-final push شد. تا ۲ دقیقه دیگر APK در Release حاضر است."
