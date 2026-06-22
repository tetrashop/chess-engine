#!/usr/bin/env bash
# offline_add_icon.sh – افزودن آیکون PNG به‌صورت آفلاین (بدون نیاز به اینترنت)

set -e
cd ~/chess-engine

echo "=== ۱. ایجاد پوشه‌های رزولوشن ==="
mkdir -p bw-project/src/main/res/mipmap-hdpi
mkdir -p bw-project/src/main/res/mipmap-mdpi
mkdir -p bw-project/src/main/res/mipmap-xhdpi
mkdir -p bw-project/src/main/res/mipmap-xxhdpi

echo "=== ۲. ساخت آیکون PNG (۴۸x۴۸) با Base64 ==="
# این یک آیکون سادهٔ شطرنج (اسب سیاه در زمینهٔ طلایی) است که به صورت Base64 کد شده.
# حجم آن بسیار کم است و در هر شرایطی کار می‌کند.

ICON_BASE64="iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAAB+ElEQVR4nO2Zz0sUYRjHP8OMMy66q/9AWmlapAdBPHQQgujUQfAPEDoEdakOQYeO0SHo2KF/IOjUoaBDtEePHYruuq67+z7PjO+HvR8HZ9adnZ3VjWcf+DIz8Hufed7nmfd5n4EBotFoNBqNRqPRaDQajUaj0Wg0Go1Go9FoNBqNRqPRaD4FL4BJYCsQBPpdzAcNgJ3Ai0DgAEQDOgOJ3AP3gNuBtn2gC3A1x4y8ANQH0BhQz1PgEbif47w3cA+81hN4AJyC30v4DEQ3eL7mGeB2xYGeBHqBAW9AN7zWeY5twHcF2gVMAa3VhoE+UA+Yk+Bh9n5hjTyoB6IDwLqsF6IXiJr83Ngo48ocqAXnAU9AoRrIqV7iFvMgwG0gApHqgNbB0woLla6Bwh9n4Fn2nXsA9AFgXAPR8UuOBXcBb3J/oMCDy3o15x+oAxUBzYLKAEjBvJ0H7r4HaC+BZkvP8j6QKbU6LtGgSBFQi4CZ/+HFylILAhWrwNLMnC6ATNDnMl45M2+geAVIfkNE8N5T7JVkB9kKcJ+bDUAmtJ8BOpIDTCR1xRpoFQuWpP6C2ArQArRsoQDHN81/XA6UaFmxjJ80pLd4ySYDRB/AqBvJ0UplQGqJo2/AheJPx3ygf+nsYFEyjBmS7kQJlg7mQLMc2wTsaq00Go1Go9H8L/wFlpxV5YcP+50AAAAASUVORK5CYII="

# تابع decode و ذخیره
decode_and_save() {
    echo "$ICON_BASE64" | base64 -d > "$1"
    echo "✅ آیکون در $1 ذخیره شد."
}

decode_and_save bw-project/src/main/res/mipmap-hdpi/ic_launcher.png
decode_and_save bw-project/src/main/res/mipmap-mdpi/ic_launcher.png
decode_and_save bw-project/src/main/res/mipmap-xhdpi/ic_launcher.png
decode_and_save bw-project/src/main/res/mipmap-xxhdpi/ic_launcher.png

echo "=== ۳. افزودن android:icon به AndroidManifest.xml ==="
if [ -f bw-project/src/main/AndroidManifest.xml ]; then
    if grep -q 'android:icon' bw-project/src/main/AndroidManifest.xml; then
        sed -i 's|android:icon="[^"]*"|android:icon="@mipmap/ic_launcher"|' bw-project/src/main/AndroidManifest.xml
        echo "✅ android:icon به‌روزرسانی شد."
    else
        sed -i '/<application/a\        android:icon="@mipmap/ic_launcher"' bw-project/src/main/AndroidManifest.xml
        echo "✅ android:icon اضافه شد."
    fi
else
    echo "❌ فایل AndroidManifest.xml پیدا نشد!"
    exit 1
fi

echo "=== ۴. Commit و Push ==="
git add -A
git commit -m "Add offline chess icon (Base64 PNG)"
git push origin main

echo ""
echo "✅ آیکون برنامه با موفقیت اضافه شد (کاملاً آفلاین)."
echo "🚀 حالا یک تگ جدید بزنید:"
echo "   git tag v5.0.3"
echo "   git push origin v5.0.3"
echo "📱 پس از build، APK دارای آیکون شطرنج خواهد بود و در لیست برنامه‌ها دیده می‌شود."
