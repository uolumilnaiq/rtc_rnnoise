#!/bin/bash

# ==============================================================================
# RNNoise Android 自动化 UI 黑盒测试脚本 (增加启动稳定性)
# ==============================================================================

PACKAGE_NAME="com.rtc.rnnoise.rtc_rnnoise_example"
MAIN_ACTIVITY=".MainActivity"

echo "----------------------------------------------------"
echo "🚀 开始 RNNoise Android 自动化黑盒测试"
echo "----------------------------------------------------"

# 1. 检查 ADB
DEVICE_ID=$(adb devices | grep -v "List" | head -n 1 | awk '{print $1}')
if [ -z "$DEVICE_ID" ]; then
    echo "❌ 错误: 未发现已连接的 Android 设备"
    exit 1
fi
echo "✅ 发现设备: $DEVICE_ID"

# 尝试点亮屏幕
adb shell input keyevent 224

# 2. 准备环境
echo ">>> [1/4] 重启应用并清理日志..."
adb shell am force-stop $PACKAGE_NAME
adb logcat -c
adb shell am start -n "$PACKAGE_NAME/$PACKAGE_NAME$MAIN_ACTIVITY"

# 获取坐标函数
get_coords() {
    local target=$1
    adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1
    local xml=$(adb shell cat /sdcard/ui.xml | tr -d '\r\n')
    local line=$(echo "$xml" | grep -oE "<node [^>]* (text|content-desc)=\"$target\" [^>]* bounds=\"[^\"]*\"" | head -n 1)
    if [ -z "$line" ]; then echo ""; return; fi
    local clean_coords=$(echo "$line" | grep -oE "bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"" | sed 's/[^0-9]/ /g' | xargs)
    read -r x1 y1 x2 y2 <<< "$clean_coords"
    echo "$(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 ))"
}

wait_for_element() {
    local name=$1
    local timeout=$2
    local count=0
    echo ">>> 等待界面加载: '$name' ..."
    while [ $count -lt $timeout ]; do
        local coords=$(get_coords "$name")
        if [ -n "$coords" ]; then 
            echo "✅ 发现按钮，额外等待 3s 确保 Flutter 响应..."
            sleep 3
            echo "$coords"
            return 0 
        fi
        sleep 2
        count=$((count + 2))
        echo "    ... 探测中 ($count/${timeout}s)"
    done
    return 1
}

# 3. 点击开始
COORDS_RESULT=$(wait_for_element "开始测试" 40)
if [ $? -eq 0 ]; then
    COORDS=$(echo "$COORDS_RESULT" | tail -n 1)
    echo ">>> [2/4] 点击“开始测试”..."
    adb shell input tap $COORDS
    echo "✅ 已点击坐标: $COORDS"
else
    echo "❌ 错误: 界面加载超时或白屏未结束"
    exit 1
fi

# 4. 验证 VAD 数据
echo ">>> [3/4] 监控实时 AI 处理心跳 (10 秒)..."
# 如果没有看到心跳，尝试补点一下（防止第一次点击在白屏期间丢失）
sleep 5
VAD_EXISTS=$(adb logcat -d | grep "RNNoise_Status")
if [ -z "$VAD_EXISTS" ]; then
    echo "⚠️ 未检测到心跳，尝试补点一次..."
    adb shell input tap $COORDS
fi

sleep 10
VAD_LOGS=$(adb logcat -d | grep "RNNoise_Status" | tail -n 5)
if [ -n "$VAD_LOGS" ]; then
    echo "✅ [PASS] 检测到实时处理心跳"
    echo "$VAD_LOGS"
else
    echo "❌ [FAIL] 无 VAD 输出，请检查麦克风权限或点击是否生效"
fi

# 5. 总结并清理
echo "----------------------------------------------------"
echo "🏁 测试总结"
echo "----------------------------------------------------"
FINAL_VAD=$(adb logcat -d | grep "RNNoise_Status" | tail -n 1 | grep -o "VAD=[0-9.]*")
if [ -n "$FINAL_VAD" ]; then
    echo "✅ 状态: 成功运行"
    echo "✅ 最新 VAD 指标: $FINAL_VAD"
else
    echo "❌ 状态: 运行异常"
fi

echo ">>> [4/4] 测试结束，正在关闭应用..."
adb shell am force-stop $PACKAGE_NAME
echo "✅ 已清理后台进程"
echo "----------------------------------------------------"
