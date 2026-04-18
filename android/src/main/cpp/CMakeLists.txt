cmake_minimum_required(VERSION 3.10.2)

project(rtc_rnnoise)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../)
set(CPP_SRC_DIR ${ROOT_DIR}/src/cpp)
set(THIRD_PARTY_DIR ${CPP_SRC_DIR}/third_party)

# RNNoise 源码 (基于本地成功编译的状态)
set(RNNOISE_SRC
    ${THIRD_PARTY_DIR}/rnnoise/src/denoise.c
    ${THIRD_PARTY_DIR}/rnnoise/src/rnn.c
    ${THIRD_PARTY_DIR}/rnnoise/src/pitch.c
    ${THIRD_PARTY_DIR}/rnnoise/src/kiss_fft.c
    ${THIRD_PARTY_DIR}/rnnoise/src/celt_lpc.c
    ${THIRD_PARTY_DIR}/rnnoise/src/nnet.c
    ${THIRD_PARTY_DIR}/rnnoise/src/nnet_default.c
    ${THIRD_PARTY_DIR}/rnnoise/src/parse_lpcnet_weights.c
    ${THIRD_PARTY_DIR}/rnnoise/src/rnnoise_data.c
    ${THIRD_PARTY_DIR}/rnnoise/src/rnnoise_tables.c
)

# SpeexDSP 源码
set(SPEEXDSP_SRC
    ${THIRD_PARTY_DIR}/speexdsp/libspeexdsp/resample.c
)

# 插件胶水代码
set(PLUGIN_SRC
    ${CPP_SRC_DIR}/rnnoise_engine.cpp
    ${CPP_SRC_DIR}/rnnoise_api.cpp
)

if(ANDROID)
    list(APPEND PLUGIN_SRC jni_bridge.cpp)
endif()

include_directories(
    ${CPP_SRC_DIR}
    ${THIRD_PARTY_DIR}/rnnoise/include
    ${THIRD_PARTY_DIR}/rnnoise/src
    ${THIRD_PARTY_DIR}/speexdsp/include
    ${THIRD_PARTY_DIR}/speexdsp/include/speex
    ${THIRD_PARTY_DIR}/speexdsp/libspeexdsp
    ${THIRD_PARTY_DIR}/speexdsp
)

# 关键宏定义
add_definitions(-DHAVE_CONFIG_H -DEXPORT= -DFLOATING_POINT -DRANDOM_PREFIX=rtc_rnnoise_ -DRNNOISE_BUILD)

# 默认生成动态库，除非指定
if(NOT LIB_TYPE)
    set(LIB_TYPE SHARED)
endif()

# 生成库
add_library(rtc_rnnoise ${LIB_TYPE}
    ${RNNOISE_SRC}
    ${SPEEXDSP_SRC}
    ${PLUGIN_SRC}
)

target_link_libraries(rtc_rnnoise log)
