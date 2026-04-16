#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/wangxinran/StudioProjects/rtc-rnnoise/ios/build_ios
  make -f /Users/wangxinran/StudioProjects/rtc-rnnoise/ios/build_ios/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/wangxinran/StudioProjects/rtc-rnnoise/ios/build_ios
  make -f /Users/wangxinran/StudioProjects/rtc-rnnoise/ios/build_ios/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "MinSizeRel"; then :
  cd /Users/wangxinran/StudioProjects/rtc-rnnoise/ios/build_ios
  make -f /Users/wangxinran/StudioProjects/rtc-rnnoise/ios/build_ios/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "RelWithDebInfo"; then :
  cd /Users/wangxinran/StudioProjects/rtc-rnnoise/ios/build_ios
  make -f /Users/wangxinran/StudioProjects/rtc-rnnoise/ios/build_ios/CMakeScripts/ReRunCMake.make
fi

