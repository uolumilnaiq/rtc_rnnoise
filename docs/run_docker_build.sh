#!/bin/bash
# run_docker_build.sh - 运行 Docker 容器进行编译
# 支持增量编译，检测已有容器则复用

set -e

IMAGE_NAME="rtc-builder"
IMAGE_TAG="latest"
CONTAINER_NAME="rtc-builder-run"

# 默认路径
FLUTTER_MODULE_PATH=$(pwd)/../flutter_module
ANDROID_PROJECT_PATH=$(pwd)/../MyApplicationForFlutter
OUTPUT_DIR=$(pwd)/output

BUILD_APK=false

# 解析参数
while getopts "f:a:o:h" opt; do
    case $opt in
        f) FLUTTER_MODULE_PATH=$OPTARG ;;
        a) ANDROID_PROJECT_PATH=$OPTARG ;;
        o) OUTPUT_DIR=$OPTARG ;;
        h)
            echo "用法: $0 [-f flutter模块路径] [-a Android项目路径] [-o 输出目录] [--with-apk]"
            echo "示例: $0 -f /abs/path/flutter_module -a /abs/path/MyApplicationForFlutter -o /abs/path/output"
            exit 0
            ;;
    esac
done

# 解析 --with-apk
for arg in "$@"; do
    if [ "$arg" = "--with-apk" ]; then
        BUILD_APK=true
    fi
done

# 转换为绝对路径
FLUTTER_MODULE_PATH=$(realpath "$FLUTTER_MODULE_PATH")
ANDROID_PROJECT_PATH=$(realpath "$ANDROID_PROJECT_PATH")
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

echo "=========================================="
echo "  Docker 容器编译"
echo "=========================================="
echo "Flutter Module: $FLUTTER_MODULE_PATH"
echo "Android Project: $ANDROID_PROJECT_PATH"
echo "Output Dir: $OUTPUT_DIR"
echo "Build APK: $BUILD_APK"
echo ""

# 检查镜像是否存在，不存在则尝试加载
if ! docker image inspect ${IMAGE_NAME}:${IMAGE_TAG} &> /dev/null; then
    echo "[0/3] 加载 Docker 镜像..."
    if [ -f "${IMAGE_NAME}.tar" ]; then
        docker load -i ${IMAGE_NAME}.tar
    else
        echo "错误: 镜像 ${IMAGE_NAME}:${IMAGE_TAG} 不存在，且找不到 ${IMAGE_NAME}.tar"
        exit 1
    fi
else
    echo "[0/3] 镜像已存在，跳过加载"
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 检查容器是否存在
CONTAINER_EXISTS=false
CONTAINER_RUNNING=false

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    CONTAINER_EXISTS=true
    echo "[1/3] 容器已存在"
    
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        CONTAINER_RUNNING=true
        echo "     容器运行中"
    else
        echo "     容器已停止"
    fi
else
    echo "[1/3] 创建新容器"
fi

# 构建参数
BUILD_ARGS="-v $FLUTTER_MODULE_PATH:/workspace/flutter_module"
BUILD_ARGS="$BUILD_ARGS -v $ANDROID_PROJECT_PATH:/workspace/MyApplicationForFlutter"
BUILD_ARGS="$BUILD_ARGS -v $OUTPUT_DIR:/workspace/output"

if [ "$BUILD_APK" = true ]; then
    BUILD_ARGS="$BUILD_ARGS --with-apk"
fi

# 根据容器状态决定操作
if [ "$CONTAINER_EXISTS" = true ]; then
    if [ "$CONTAINER_RUNNING" = true ]; then
        echo "[2/3] 容器运行中，直接执行编译..."
        docker exec -it $CONTAINER_NAME /workspace/build.sh $BUILD_ARGS
    else
        echo "[2/3] 启动已存在的容器并执行编译..."
        docker start $CONTAINER_NAME
        docker exec -it $CONTAINER_NAME /workspace/build.sh $BUILD_ARGS
    fi
else
    echo "[2/3] 创建并运行容器..."
    docker run -it --name $CONTAINER_NAME $BUILD_ARGS ${IMAGE_NAME}:${IMAGE_TAG}
fi

echo "[3/3] 编译完成"

echo ""
echo "=========================================="
echo "  构建完成！"
echo "=========================================="
echo "产物目录: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR/"
echo ""
echo "注意: 容器已停止，可通过以下命令再次运行:"
echo "  docker start ${CONTAINER_NAME} && docker exec -it ${CONTAINER_NAME} /workspace/build.sh"
echo "=========================================="