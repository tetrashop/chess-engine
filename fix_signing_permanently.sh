#!/usr/bin/env bash
# fix_signing_permanently.sh – رفع قطعی تداخل نصب و امضای یکسان برای همیشه

cd ~/chess-engine

echo "🔐 ایجاد کلید امضای دائمی (اگر وجود ندارد)..."
if [ ! -f bw-project/ramin-chess.keystore ]; then
    cd bw-project
    keytool -genkey -v \
      -keystore ramin-chess.keystore \
      -alias raminchess \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -storepass ramin123 -keypass ramin123 \
      -dname "CN=Ramin Ejlal, OU=Dev, O=Tetrashop, L=Tehran, ST=Tehran, C=IR"
    cd ~/chess-engine
    echo "✅ کلید جدید ساخته شد."
else
    echo "✅ کلید از قبل وجود دارد."
fi

echo "⚙️ تنظیم build.gradle برای امضای یکسان در همهٔ buildها..."
cat > bw-project/build.gradle << 'EOF'
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.2.0'
    }
}
apply plugin: 'com.android.application'

android {
    namespace 'com.ramin.chess'
    compileSdk 34
    defaultConfig {
        applicationId 'com.ramin.chess'
        minSdk 21
        targetSdk 34
        versionCode 7
        versionName "1.3.0"
    }
    signingConfigs {
        release {
            storeFile file('ramin-chess.keystore')
            storePassword 'ramin123'
            keyAlias 'raminchess'
            keyPassword 'ramin123'
        }
    }
    buildTypes {
        debug {
            signingConfig signingConfigs.release   // ← نسخهٔ Debug هم با کلید Release امضا شود
        }
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

repositories {
    google()
    mavenCentral()
}
EOF

echo "✅ تنظیمات امضا یکسان شد."

echo "⚙️ به‌روزرسانی workflow برای ساخت APK امضاشدهٔ Release..."
cat > .github/workflows/release-apk.yml << 'EOF'
name: Build APK

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
          files: bw-project/app/build/outputs/apk/release/app-release.apk
          tag_name: ${{ github.event.release.tag_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

echo "📦 Commit و Push..."
git add -A
git commit -m "Fix signing permanently – all builds use same key, versionCode 7"
git push origin main

echo ""
echo "✅ همه چیز آماده است!"
echo "🚀 یک Release جدید با تگ v1.3.0 در گیت‌هاب بسازید."
echo "   پس از build، فایل app-release.apk را دانلود کنید."
echo "   اگر نسخه‌ای از قبل روی گوشی دارید، فقط کافی است APK جدید را نصب کنید – جایگزین می‌شود."
