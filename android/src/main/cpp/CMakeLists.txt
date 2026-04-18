cmake_minimum_required(VERSION 3.10.2)

project(rtc_rnnoise)

# 注意：此 CMakeLists.txt 仅用于 IDE (如 Android Studio) 导航和索引现有胶水代码。
# 实际构建已在 build.gradle 中通过 jniLibs 引用预编译的 .so 文件。

set(ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../)
set(CPP_SRC_DIR ${ROOT_DIR}/src/cpp)
set(THIRD_PARTY_DIR ${CPP_SRC_DIR}/third_party)

# 仅保留插件胶水层源码
set(PLUGIN_SRC
    ${CPP_SRC_DIR}/rnnoise_engine.cpp
    ${CPP_SRC_DIR}/rnnoise_api.cpp
    jni_bridge.cpp
)

include_directories(
    ${CPP_SRC_DIR}
    ${THIRD_PARTY_DIR}/rnnoise/include
    ${THIRD_PARTY_DIR}/speexdsp/include
    ${THIRD_PARTY_DIR}/speexdsp/include/speex
)

add_definitions(-DHAVE_CONFIG_H -DEXPORT= -DFLOATING_POINT -DRANDOM_PREFIX=rtc_rnnoise_)

# 即使不用于构建，保持 add_library 也能让 IDE 正确识别源文件关联
add_library(rtc_rnnoise SHARED ${PLUGIN_SRC})

target_link_libraries(rtc_rnnoise log)
