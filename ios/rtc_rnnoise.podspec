Pod::Spec.new do |s|
  s.name             = 'rtc_rnnoise'
  s.version          = '0.1.0'
  s.summary          = 'A high-performance AI noise reduction plugin for Flutter WebRTC.'
  s.description      = <<-DESC
A high-performance AI noise reduction plugin for Flutter WebRTC, based on RNNoise. 
Features real-time VAD and zero-latency native audio processing via pre-compiled binaries.
                       DESC
  s.homepage         = 'https://github.com/your-username/rtc_rnnoise'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  
  s.source_files = 'Classes/**/*', '../src/cpp/**/*.{h,hpp}'
  
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # 使用 XCFramework，支持真机 (iphoneos) 和 M3 模拟器 (iphonesimulator)
  s.vendored_frameworks = 'libs/rtc_rnnoise.xcframework'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) HAVE_CONFIG_H=1 FIXED_POINT=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../src/cpp" "${PODS_TARGET_SRCROOT}/../src/cpp/third_party/rnnoise/include" "${PODS_TARGET_SRCROOT}/../src/cpp/third_party/speexdsp/include"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
