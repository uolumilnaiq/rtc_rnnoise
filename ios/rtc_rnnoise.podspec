Pod::Spec.new do |s|
  s.name             = 'rtc_rnnoise'
  s.version          = '0.1.0'
  s.summary          = 'A high-performance AI noise reduction plugin for Flutter WebRTC.'
  s.description      = 'High-performance AI noise reduction based on RNNoise v0.2. Features zero-latency native processing and XCFramework support.'
  s.homepage         = 'https://github.com/uolumilnaiq/rtc_rnnoise'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  
  # 仅包含胶水代码和头文件
  s.source_files = 'Classes/*.{h,m,mm,swift}', '../src/cpp/**/*.{h,hpp}'
  
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # 使用 XCFramework，支持真机和 M3 模拟器
  s.vendored_frameworks = 'libs/RtcRnnoiseNative.xcframework'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) HAVE_CONFIG_H=1 FLOATING_POINT=1 EXPORT= RANDOM_PREFIX=rtc_rnnoise_ RNNOISE_BUILD=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/../src/cpp" "$(PODS_TARGET_SRCROOT)/../src/cpp/third_party/rnnoise/include" "$(PODS_TARGET_SRCROOT)/../src/cpp/third_party/speexdsp/include"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
