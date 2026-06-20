#!/usr/bin/env bash
# prepare_for_market.sh – آماده‌سازی برنامه برای فروش در بازار

cd ~/chess-engine

echo "=== ۱. ایجاد فایل‌های قانونی ==="
mkdir -p legal

# Privacy Policy (نمونه)
cat > legal/PRIVACY_POLICY.md << 'EOF'
# سیاست حفظ حریم خصوصی – شطرنج رامین اجلال

**آخرین به‌روزرسانی:** ۲۰۲۶

ما (تیم توسعه) به حریم خصوصی شما احترام می‌گذاریم. این برنامه:
- هیچ‌گونه اطلاعات شخصی (مانند نام، ایمیل، موقعیت مکانی) را جمع‌آوری نمی‌کند.
- برای بازی آنلاین با هوش مصنوعی، فقط FEN موقعیت جاری به سرور ارسال می‌شود.
- داده‌های بازی (تاریخچه، امتیازات) فقط در حافظهٔ گوشی شما ذخیره می‌شود و هرگز به جایی ارسال نمی‌شود.
- از کوکی یا فناوری ردیابی استفاده نمی‌شود.

در صورت هرگونه سوال، با ما تماس بگیرید: tetrashop@example.com
EOF

# Terms of Service
cat > legal/TERMS_OF_SERVICE.md << 'EOF'
# شرایط استفاده – شطرنج رامین اجلال

۱. این برنامه یک موتور شطرنج سرگرمی/آموزشی است و هیچ ضمانتی برای عملکرد آن وجود ندارد.
۲. کاربر حق استفاده از برنامه را فقط برای مقاصد قانونی دارد.
۳. کپی‌برداری، مهندسی معکوس یا توزیع غیرمجاز برنامه ممنوع است.
۴. توسعه‌دهنده مسئولیتی در قبال آسیب‌های ناشی از استفاده از برنامه ندارد.

حق هرگونه تغییر در این شرایط برای توسعه‌دهنده محفوظ است.
EOF

# License (MIT)
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2026 Ramin Ejlal (tetrashop)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

echo "=== ۲. ایجاد Keystore برای امضای Release ==="
cd bw-project
if [ ! -f ramin-chess.keystore ]; then
    keytool -genkey -v \
      -keystore ramin-chess.keystore \
      -alias raminchess \
      -keyalg RSA \
      -keysize 2048 \
      -validity 10000 \
      -storepass ramin123 \
      -keypass ramin123 \
      -dname "CN=Ramin Ejlal, OU=Development, O=Tetrashop, L=Tehran, S=Tehran, C=IR"
    echo "Keystore ایجاد شد."
else
    echo "Keystore از قبل وجود دارد."
fi
cd ..

echo "=== ۳. تنظیم build.gradle برای امضای Release ==="
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
        versionCode 2
        versionName '1.0.0'
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

echo "=== ۴. ساخت APK امضاشدهٔ Release ==="
cd bw-project
./gradlew assembleRelease
cd ..

echo ""
echo "✅ APK Release با موفقیت ساخته شد."
echo "📍 مسیر فایل: bw-project/app/build/outputs/apk/release/app-release.apk"
echo ""
echo "📦 برای انتشار در Google Play:"
echo "  ۱. حساب Google Play Console بسازید (25 دلار یک‌بار پرداخت)."
echo "  ۲. یک برنامهٔ جدید ایجاد کنید."
echo "  ۳. فایل app-release.apk را در بخش App Bundle/APK آپلود کنید."
echo "  ۴. قیمت را در بخش Pricing & Distribution (پولی یا رایگان با خرید درون‌برنامه‌ای) تنظیم کنید."
echo "  ۵. Privacy Policy و Terms of Service را از فایل‌های legal/ آپلود کنید."
echo ""
echo "💰 پیشنهاد قیمت: با توجه به امکانات (هوش مصنوعی، سطوح، مربی و...)"
echo "   قیمت مناسب بین ۲ تا ۵ دلار (یا معادل ریالی) پیشنهاد می‌شود."
echo "   می‌توانید نسخهٔ رایگان با تبلیغات و نسخهٔ پولی بدون تبلیغات نیز عرضه کنید."
