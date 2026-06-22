#!/usr/bin/env bash
# add_app_icon.sh – افزودن آیکون PNG به برنامه اندروید

set -e
cd ~/chess-engine

echo "=== ۱. ایجاد پوشه‌های رزولوشن‌های مختلف ==="
mkdir -p bw-project/src/main/res/mipmap-hdpi
mkdir -p bw-project/src/main/res/mipmap-mdpi
mkdir -p bw-project/src/main/res/mipmap-xhdpi
mkdir -p bw-project/src/main/res/mipmap-xxhdpi

echo "=== ۲. دانلود آیکون شطرنج (چند سایز مختلف) ==="
# از یک منبع معتبر آیکون شطرنج با کیفیت مناسب
curl -L -o bw-project/src/main/res/mipmap-hdpi/ic_launcher.png "https://img.icons8.com/color/48/chess.png"
curl -L -o bw-project/src/main/res/mipmap-mdpi/ic_launcher.png "https://img.icons8.com/color/48/chess.png"
curl -L -o bw-project/src/main/res/mipmap-xhdpi/ic_launcher.png "https://img.icons8.com/color/96/chess.png"
curl -L -o bw-project/src/main/res/mipmap-xxhdpi/ic_launcher.png "https://img.icons8.com/color/144/chess.png"

echo "=== ۳. افزودن android:icon به AndroidManifest.xml (با sed) ==="
if [ -f bw-project/src/main/AndroidManifest.xml ]; then
    # بررسی کن که آیا android:icon وجود دارد یا نه
    if grep -q 'android:icon' bw-project/src/main/AndroidManifest.xml; then
        # اگر وجود داشت، فقط مقدار آن را به‌روزرسانی کن
        sed -i 's|android:icon="[^"]*"|android:icon="@mipmap/ic_launcher"|' bw-project/src/main/AndroidManifest.xml
        echo "✅ android:icon به‌روزرسانی شد."
    else
        # اگر وجود نداشت، آن را به خط بعد از <application اضافه کن
        sed -i '/<application/a\        android:icon="@mipmap/ic_launcher"' bw-project/src/main/AndroidManifest.xml
        echo "✅ android:icon اضافه شد."
    fi
else
    echo "❌ فایل AndroidManifest.xml پیدا نشد!"
    exit 1
fi

echo "=== ۴. Commit و Push ==="
git add -A
git commit -m "Add chess icon to Android app (all densities)"
git push origin main

echo ""
echo "✅ آیکون برنامه با موفقیت تنظیم شد."
echo "🚀 حالا یک تگ جدید بزنید:"
echo "   git tag v5.0.2"
echo "   git push origin v5.0.2"
echo "📱 پس از build، APK دارای آیکون شطرنج خواهد بود."
