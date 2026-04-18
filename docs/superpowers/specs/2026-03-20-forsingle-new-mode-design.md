# ForSingle新模式需求与实现设计

## 1. 需求概述

在现有ForSingle和ForGroup拍照功能基础上，增加以下逻辑：
- ForSingle拍照成功后显示"拍照成功"提示
- ForGroup拍照成功后显示"正在进行识别请稍后"，调用HTTP接口
  - HTTP成功：显示"识别成功"
  - HTTP失败：显示"识别失败"，自动切换到ForSingle新模式
- ForSingle新模式：前置摄像头 + 红色标题 + 800x600红色虚线框，拍照后截取保存

## 2. 需求详细说明

### 2.1 ForSingle模式（原有）

| 场景 | 行为 |
|------|------|
| 拍照成功 | 弹出"拍照成功"，回调onPhotoTakeSuccess |

### 2.2 ForGroup模式

| 场景 | 行为 |
|------|------|
| 拍照成功 | 弹出"正在进行识别请稍后"，调用HTTP接口 |
| HTTP调用成功 | 弹出"识别成功"，回调onPhotoTakeSuccess，关闭模式 |
| HTTP调用失败 | 弹出"识别失败"，退出ForGroup模式，自动进入ForSingle新模式 |

### 2.3 ForSingle新模式（ForGroup失败后进入）

| 属性 | 值 |
|------|-----|
| 触发条件 | ForGroup模式HTTP调用失败后自动切换 |
| 摄像头 | 前置 |
| 标题 | "请外拓人员站在这里"（红色，20px，加粗） |
| 红色虚线框 | 600x800，2px边框，居中显示 |
| 拍照后行为 | 从虚线框区域截取800x600，保存为`时间戳_crop.jpg` |
| 成功提示 | 弹出"拍照成功"，回调onPhotoTakeSuccess，关闭模式 |

## 3. UI布局

ForSingle新模式从上到下均匀排列：
1. 红色标题 "请外拓人员站在这里"
2. 800x600红色虚线框（居中，不遮挡拍照按钮）
3. 拍照按钮

## 4. 文件修改清单

| 文件 | 修改内容 |
|------|---------|
| `lib/features/xchatkit_adapter/core/xchatkit_adapter.dart` | BusinessPhotoMode枚举新增 `singleWithFrame` 模式 |
| `lib/screens/room/ui/business_photo_overlay.dart` | 新增ForSingle新模式UI（红色标题+红色虚线框+前置摄像头） |
| `lib/screens/room/ui/photo_manager.dart` | Toast提示、模式切换逻辑、HTTP失败处理、截图保存 |
| `lib/screens/room/room.dart` | ForGroup失败后切换到ForSingle新模式的入口 |

## 5. 实现逻辑

### 5.1 模式切换流程

```
ForGroup模式:
  拍照成功 → 显示Toast("正在进行识别请稍后") → callBusinessPhotoApi()
    ├── 成功 → 显示Toast("识别成功") → onPhotoTakeSuccess回调 → 关闭模式
    └── 失败 → 显示Toast("识别失败") → 切换到ForSingle新模式

ForSingle新模式:
  进入(toggleCamera=false, showFrame=true) → 显示红色标题+红色虚线框
    → 拍照 → 从虚线框截取800x600区域 → 保存为{时间戳}_crop.jpg
    → 显示Toast("拍照成功") → onPhotoTakeSuccess回调 → 关闭模式
```

### 5.2 截图实现

方案：先拍摄完整图片，拍照后从图片中央截取600x800区域
- 虚线框位置：居中
- 截图区域：600x800像素

### 5.3 回调处理

- ForGroup失败后切换到ForSingle新模式，使用新的callback
- ForSingle新模式拍照成功后回调onPhotoTakeSuccess（复用BusinessPhotoParams中的回调）