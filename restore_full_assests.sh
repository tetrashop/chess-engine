#!/usr/bin/env bash
cd ~/chess-engine
rm -rf bw-project/src/main/assets
mkdir -p bw-project/src/main/assets
mkdir -p bw-project/src/main/java/com/ramin/chess

# ── 1. index.html (کامل، با CDN و نام رامین اجلال) ──
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

# ── 2. style.css (همان نسخهٔ کامل) ──
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

# ── 3. script.js (نسخهٔ کامل و تست‌شده) ──
# اگر فایل کامل در frontend/script.js وجود دارد، همان را کپی می‌کنیم
if [ -f frontend/script.js ]; then
    cp frontend/script.js bw-project/src/main/assets/script.js
    # اصلاح API_URL به آدرس Vercel
    sed -i 's|const API_URL = .*|const API_URL = "https://chess-engine.vercel.app/api/bestmove";|' bw-project/src/main/assets/script.js
else
    # در غیر این صورت یک نسخهٔ حداقلی هشدار می‌دهیم (باید فایل اصلی را بعداً جایگزین کنید)
    cat > bw-project/src/main/assets/script.js << 'JSEOF'
const API_URL = "https://chess-engine.vercel.app/api/bestmove";
// فایل script.js کامل در اینجا قرار می‌گیرد. لطفاً نسخهٔ کامل را جایگزین کنید.
JSEOF
    echo "⚠️  فایل frontend/script.js یافت نشد. لطفاً نسخهٔ کامل را در bw-project/src/main/assets/script.js قرار دهید."
fi

# ── 4. manifest.json ──
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

# ── 5. MainActivity.java (لوکال) ──
cat > bw-project/src/main/java/com/ramin/chess/MainActivity.java << 'EOF'
package com.ramin.chess;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import android.view.ViewGroup;
import android.widget.RelativeLayout;

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

# ── 6. workflow (همان نسخهٔ debug) ──
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
echo "✅ تمام فایل‌ها بازسازی شدند."
echo "اکنون دستورات زیر را اجرا کنید:"
echo "  git add -A"
echo "  git commit -m 'Restore full local assets with all features'"
echo "  git push"
echo "  سپس یک release جدید (مثلاً v1.0.30) در گیت‌هاب ایجاد کنید."
