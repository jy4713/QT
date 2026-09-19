export PATH="/c/Utils/flutter/bin:$PATH"
export ANDROID_HOME="C:/Users/jy030/AppData/Local/Android/Sdk"
flutter build apk --release > build-apk4.log 2>&1
echo "APK_EXIT:$?" >> build-apk4.log
flutter build web --release > build-web4.log 2>&1
echo "WEB_EXIT:$?" >> build-web4.log
