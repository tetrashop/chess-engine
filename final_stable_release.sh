#!/usr/bin/env bash
# final_stable_release.sh – آخرین نسخهٔ پایدار، با پشتیبان Artifact

set -e
cd ~/chess-engine

echo "🔍 ۱. رفتن به main و به‌روزرسانی (در صورت در دسترس بودن اینترنت)"
git checkout main
git pull origin main || echo "⚠️ pull ناموفق بود (اینترنت قطع است). ادامه می‌دهیم..."

echo "🛠️ ۲. تعمیر و بازسازی فایل‌های ضروری"

# آیکون Vector (XML) – بدون PNG
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

# حذف PNGهای احتمالی
rm -f bw-project/src/main/res/mipmap-*/ic_launcher.png

# AndroidManifest.xml
cat > bw-project/src/main/AndroidManifest.xml << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.ramin.chess">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:icon="@drawable/ic_launcher"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.NoTitleBar">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
XML

# strings.xml
mkdir -p bw-project/src/main/res/values
cat > bw-project/src/main/res/values/strings.xml << 'XML'
<resources><string name="app_name">شطرنج رامین اجلال</string></resources>
XML

# build.gradle (نسخهٔ جدید)
sed -i 's/versionCode .*/versionCode 700/' bw-project/build.gradle
sed -i 's/versionName .*/versionName "7.0.0"/' bw-project/build.gradle

echo "⚙️ ۳. ساخت Workflow (Release + Artifact)"
mkdir -p .github/workflows
cat > .github/workflows/release-apk.yml << 'YML'
name: Build Final APK

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
      - name: Upload APK to Release
        uses: softprops/action-gh-release@v2
        with:
          files: bw-project/app/build/outputs/apk/debug/app-debug.apk
          tag_name: ${{ github.ref_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Upload APK to Artifacts (backup)
        uses: actions/upload-artifact@v4
        with:
          name: ChessEnginePy-APK-${{ github.ref_name }}
          path: bw-project/app/build/outputs/apk/debug/app-debug.apk
YML

echo "📦 ۴. Commit، Push و تگ"
git add -A
git commit -m "Final stable v7.0.0 – auto-release + artifact backup"
git push origin main || echo "⚠️ push به main ناموفق بود. با اینترنت بهتر دوباره تلاش کنید."
git tag v7.0.0
git push origin v7.0.0 || echo "⚠️ push تگ ناموفق بود. بعداً می‌توانید دستی push کنید: git push origin v7.0.0"

echo ""
echo "✅ اسکریپت با موفقیت اجرا شد."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 دریافت APK:"
echo "  ۱. به تب Actions در گیت‌هاب بروید:"
echo "     https://github.com/tetrashop/chess-engine/actions"
echo "  ۲. روی آخرین اجرا (Build Final APK) کلیک کنید."
echo "  ۳. در پایین صفحه، بخش Artifacts را ببینید."
echo "  ۴. فایل ChessEnginePy-APK-v7.0.0 را دانلود کنید."
echo "  ۵. فایل ZIP را باز کرده و app-debug.apk را استخراج کنید."
echo "  ۶. این فایل را مستقیماً در کافه‌بازار (یا هر بازار دیگر) آپلود کنید."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 اگر APK در بخش Assets ریلیز هم ظاهر شد، می‌توانید از آن استفاده کنید،"
echo "   اما Artifact همیشه به‌عنوان پشتیبان در دسترس است."
