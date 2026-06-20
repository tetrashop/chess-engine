#!/usr/bin/env bash
# final_apk_no_conflict.sh – APK بدون تداخل، با نام رامین اجلال و رابط کاربری کامل

cd ~/chess-engine
rm -rf bw-project   # پاک‌سازی کامل پروژهٔ قبلی
mkdir -p bw-project/src/main/assets
mkdir -p bw-project/src/main/java/com/ramin/chess
mkdir -p bw-project/src/main/res/raw

# ────────────── 1. فایل‌های فرانت‌اند ──────────────
cat > bw-project/src/main/assets/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>شطرنج رامین اجلال</title>
    <link rel="stylesheet" href="style.css">
    <link rel="manifest" href="manifest.json">
</head>
<body>
    <div class="container">
        <h1>♟️ شطرنج رامین اجلال</h1>
        <div class="levels-bar" id="levelsBar">
            <span class="level-dot done">۱</span><span class="level-dot done">۲</span>
            <span class="level-dot active">۳</span><span class="level-dot">۴</span>
            <span class="level-dot locked">۵</span><span class="level-dot locked">۶</span>
            <span class="level-dot locked">۷</span><span class="level-dot locked">۸</span>
        </div>
        <div class="info-panel">
            <div id="levelDisplay">سطح ۱</div>
            <div id="bonusDisplay">امتیاز: ۰</div>
            <div id="winsDisplay">برد: ۰/۳</div>
            <div id="modeIndicator">شما: سفید</div>
        </div>
        <div class="top-games-panel">
            <div id="liveGameIndicator" style="display:none;"></div>
            <h3>🏆 سه بازی برتر</h3>
            <div id="topGamesList"></div>
        </div>
        <div id="board" style="width: 400px; margin: 0 auto;"></div>
        <div class="controls">
            <button id="newGameBtn">🔄 بازی جدید</button>
            <button id="undoBtn">↩️ بازگشت</button>
            <button id="redoBtn">↪️ پیشروی</button>
            <button id="flipBtn">🔃 چرخاندن صفحه</button>
            <button id="switchColorBtn">🔀 تعویض رنگ</button>
            <button id="hintBtn">💡 نمایش حرکت‌های مجاز</button>
            <button id="coachBtn">🧠 مربی</button>
            <button id="soundToggle">🔊 صدا</button>
        </div>
        <div id="status">نوبت شما (سفید)</div>
        <div id="chatBox" class="chat-box" style="display:none;"></div>
        <div id="toast" class="toast"></div>
    </div>

    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/chess.js/0.10.3/chess.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.js"></script>
    <script src="script.js"></script>
</body>
</html>
HTMLEOF

# style.css
cat > bw-project/src/main/assets/style.css << 'CSSEOF'
body { margin:0; padding:20px; background:#1a1a1a; color:#eee; font-family:Tahoma,sans-serif; display:flex; justify-content:center; }
.container { text-align:center; max-width:550px; }
h1 { color:#f0d9b5; margin-bottom:10px; }
.levels-bar { display:flex; justify-content:center; gap:10px; margin:10px 0; }
.level-dot { display:inline-flex; align-items:center; justify-content:center; width:30px; height:30px; border-radius:50%; background:#444; color:#aaa; font-weight:bold; font-size:14px; }
.level-dot.done { background:#2e7d32; color:#fff; }
.level-dot.active { background:#f0d9b5; color:#000; box-shadow:0 0 10px #f0d9b5; }
.level-dot.locked { background:#555; color:#888; }
.info-panel { display:flex; justify-content:space-around; background:#2a2a2a; border-radius:8px; padding:8px; margin:10px 0; font-size:14px; }
.info-panel div { background:#444; padding:4px 12px; border-radius:4px; }
.top-games-panel { background:#222; border-radius:8px; padding:8px; margin:10px 0; text-align:right; }
.top-games-panel h3 { margin:0 0 5px 0; color:#f0d9b5; font-size:16px; }
.game-entry { background:#333; padding:5px 10px; margin:3px 0; border-radius:4px; cursor:pointer; font-size:13px; display:flex; justify-content:space-between; }
.game-entry:hover { background:#444; }
.controls { margin:10px 0; display:flex; flex-wrap:wrap; justify-content:center; gap:6px; }
button { background:#4a4a4a; color:#fff; border:none; padding:6px 12px; font-size:13px; border-radius:5px; cursor:pointer; transition:background 0.2s; }
button:hover { background:#666; }
button.active { background:#8b7d3c; }
#status { margin:12px 0; font-size:18px; font-weight:bold; min-height:30px; color:#f0d9b5; }
.chat-box { background:#111; border-radius:8px; padding:10px; margin:10px 0; max-height:120px; overflow-y:auto; font-size:13px; text-align:right; color:#ccc; }
.toast { position:fixed; top:20px; left:50%; transform:translateX(-50%); background:gold; color:#000; padding:8px 20px; border-radius:20px; font-weight:bold; font-size:16px; opacity:0; transition:opacity 0.5s; pointer-events:none; z-index:1000; }
.toast.show { opacity:1; }
.highlight-square { box-shadow:inset 0 0 10px 4px rgba(255,255,0,0.8) !important; }
CSSEOF

# script.js (نسخهٔ کامل با API_URL ثابت به Vercel)
# کپی از فایل موجود در frontend/script.js (اگر وجود دارد)
if [ -f frontend/script.js ]; then
    cp frontend/script.js bw-project/src/main/assets/script.js
    # اصلاح API_URL
    sed -i 's|const API_URL = .*|const API_URL = "https://chess-engine.vercel.app/api/bestmove";|' bw-project/src/main/assets/script.js
else
    # یک نسخهٔ ساده (حداقلی) در صورت نبود فایل
    cat > bw-project/src/main/assets/script.js << 'JSEOF'
const API_URL = "https://chess-engine.vercel.app/api/bestmove";
// ... (اسکریپت کامل باید اینجا قرار گیرد)
JSEOF
    echo "⚠️  فایل frontend/script.js یافت نشد – لطفاً آن را بعداً کامل کنید."
fi

# manifest.json
cat > bw-project/src/main/assets/manifest.json << 'EOF'
{
  "name": "شطرنج رامین اجلال",
  "short_name": "شطرنج",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a1a",
  "theme_color": "#f0d9b5",
  "icons": [{
    "src": "https://chessboardjs.com/img/chesspieces/wikipedia/wK.png",
    "sizes": "64x64",
    "type": "image/png"
  }]
}
EOF

# sw.js
cat > bw-project/src/main/assets/sw.js << 'EOF'
self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open('chess-v1').then((cache) => {
      return cache.addAll(['/','/style.css','/script.js','/manifest.json']);
    })
  );
});
self.addEventListener('fetch', (e) => {
  e.respondWith(caches.match(e.request).then((resp) => resp || fetch(e.request)));
});
EOF

# ────────────── 2. کد Java (نام بسته جدید: com.ramin.chess) ──────────────
cat > bw-project/src/main/java/com/ramin/chess/MainActivity.java << 'EOF'
package com.ramin.chess;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView webView = new WebView(this);
        webView.setWebViewClient(new WebViewClient());
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        webView.loadUrl("file:///android_asset/index.html");
        setContentView(webView);
    }
}
EOF

# ────────────── 3. AndroidManifest.xml (نام بسته جدید) ──────────────
cat > bw-project/src/main/AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.ramin.chess">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="true"
        android:label="شطرنج رامین اجلال"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.NoTitleBar">
        <activity android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# ────────────── 4. build.gradle (نام بسته جدید) ──────────────
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
        versionCode 1
        versionName '1.0'
    }
    buildTypes {
        release {
            minifyEnabled false
        }
    }
}

repositories {
    google()
    mavenCentral()
}
EOF

# gradle.properties
cat > bw-project/gradle.properties << 'EOF'
android.useAndroidX=true
EOF

# gradlew (اسکریپت wrapper)
cat > bw-project/gradlew << 'EOF'
#!/bin/bash
# Gradle wrapper
PRG="$0"
while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "$PRG"`/"$link"
  fi
done
APP_HOME=`dirname "$PRG"`
if [ ! -f "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" ]; then
  mkdir -p "$APP_HOME/gradle/wrapper"
  curl -L -o "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" \
    https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradle/wrapper/gradle-wrapper.jar
fi
java -cp "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain "$@"
EOF
chmod +x bw-project/gradlew

# ────────────── 5. workflow (بدون تغییر) ──────────────
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
      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - name: Setup Android SDK
        uses: android-actions/setup-android@v3
      - name: Accept Licenses
        run: |
          mkdir -p $ANDROID_HOME/licenses
          echo "d56f5187479451eabf01fb78af6dfcb131a6481e" > $ANDROID_HOME/licenses/android-sdk-license
          echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-preview-license
      - name: Build APK
        run: |
          cd bw-project
          ./gradlew assembleDebug
      - name: Upload APK
        uses: softprops/action-gh-release@v2
        with:
          files: bw-project/**/*.apk
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

echo ""
echo "✅ اسکریپت کامل شد."
echo "🚀 مراحل بعدی:"
echo "   git add -A && git commit -m 'Final APK – no conflict, Ramin Ejlal chess' && git push"
echo "   سپس یک release جدید در گیت‌هاب (مثلاً v1.0.24) ایجاد کنید."
echo "   در گوشی، اگر برنامه‌ای با نام شطرنج رامین اجلال نصب دارید، ابتدا آن را حذف کنید."
echo "   سپس APK جدید را نصب کنید."
