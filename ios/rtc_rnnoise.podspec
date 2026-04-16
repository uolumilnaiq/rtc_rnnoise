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
  
  # Only headers are needed for the public package if using vendored library
  s.source_files = 'Classes/**/*', '../src/cpp/**/*.{h,hpp}'
  
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Vendored library
  s.vendored_libraries = 'libs/librtc_rnnoise.a'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) HAVE_CONFIG_H=1 FIXED_POINT=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../src/cpp" "${PODS_TARGET_SRCROOT}/../src/cpp/third_party/rnnoise/include" "${PODS_TARGET_SRCROOT}/../src/cpp/third_party/speexdsp/include"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
