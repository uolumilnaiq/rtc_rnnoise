Pod::Spec.new do |s|
  s.name             = 'rtc_rnnoise'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter RTC RNNoise plugin.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', '../../src/cpp/**/*.{h,c,cpp}'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) HAVE_CONFIG_H=1 FIXED_POINT=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../../src/cpp" "${PODS_TARGET_SRCROOT}/../../src/cpp/third_party/rnnoise/include" "${PODS_TARGET_SRCROOT}/../../src/cpp/third_party/speexdsp/include"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
