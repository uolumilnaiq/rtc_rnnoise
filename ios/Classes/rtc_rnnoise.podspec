Pod::Spec.new do |s|
  s.name             = 'rtc_rnnoise'
  s.version          = '0.1.0'
  s.summary          = 'A high-performance AI noise reduction plugin.'
  s.description      = 'AI noise reduction based on RNNoise v0.2.'
  s.homepage         = 'https://github.com/your-username/rtc_rnnoise'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  
  s.source_files = [
    'Classes/*.{h,m,mm,swift}',
    'Classes/internal/*.{cpp}',
    'Classes/internal/rnnoise/*.{c}',
    'Classes/internal/speexdsp/*.{c}'
  ]
  
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'GCC_C_LANGUAGE_STANDARD' => 'gnu11',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) HAVE_CONFIG_H=1 FLOATING_POINT=1 EXPORT= RANDOM_PREFIX=rtc_rnnoise_ RNNOISE_BUILD=1 OUTSIDE_SPEEX=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/Classes" "$(PODS_TARGET_SRCROOT)/Classes/internal" "$(PODS_TARGET_SRCROOT)/Classes/internal/rnnoise" "$(PODS_TARGET_SRCROOT)/Classes/internal/speexdsp"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
