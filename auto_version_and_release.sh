#!/usr/bin/env bash
# auto_version_and_release.sh – افزایش خودکار versionCode و آماده‌سازی برای انتشار

cd ~/chess-engine

# مطمئن شویم روی main هستیم و همه‌چیز push شده
git checkout main
git pull origin main

# خواندن versionCode فعلی از build.gradle
CURRENT_CODE=$(grep 'versionCode ' bw-project/build.gradle | grep -o '[0-9]*')
NEW_CODE=$((CURRENT_CODE + 1))

echo "🔄 افزایش versionCode از $CURRENT_CODE به $NEW_CODE"

# به‌روزرسانی versionCode
sed -i "s/versionCode [0-9]*/versionCode $NEW_CODE/" bw-project/build.gradle

# تنظیم versionName بر اساس تاریخ (اختیاری، می‌توانید دستی تغییر دهید)
NEW_VERSION="1.2.${NEW_CODE}"
sed -i "s/versionName \"[^\"]*\"/versionName \"$NEW_VERSION\"/" bw-project/build.gradle

echo "📌 نسخهٔ جدید: $NEW_VERSION (کد $NEW_CODE)"

# کامیت و پوش
git add bw-project/build.gradle
git commit -m "Bump version to $NEW_VERSION (code $NEW_CODE)"
git push origin main

echo "✅ نسخه افزایش یافت. حالا مراحل زیر را انجام دهید:"
echo ""
echo "۱. به گیت‌هاب بروید و یک Release جدید با تگ v$NEW_VERSION ایجاد کنید."
echo "۲. بعد از ساخته شدن APK (حدود ۲ دقیقه)، آن را دانلود کنید."
echo "۳. در پنل کافه‌بازار، نسخهٔ جدید را آپلود کنید."
echo "   دیگر خطای 'شماره نسخه تکراری' نخواهید گرفت."
echo ""
echo "🔐 نکتهٔ مهم:"
echo "   - امضای برنامه (keystore) همان امضای قبلی است؛ بنابراین کاربران بدون"
echo "     حذف نسخهٔ قدیمی می‌توانند برنامه را به‌روزرسانی کنند."
echo "   - هر بار که می‌خواهید نسخهٔ جدید منتشر کنید، همین اسکریپت را اجرا کنید."
