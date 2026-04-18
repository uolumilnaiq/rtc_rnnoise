# WebSocket 通信流程详解

本文档详细说明 ClientInstanceV2 中 StandardWebSocketSession 的 request/notify 调用流程，以及协议编解码和传输层的处理机制。

## 1. 整体架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ClientInstanceV2                                 │
│  • request() / notify() 方法                                            │
│  • _handleRequest() / _handleNotification() 处理服务器推送              │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    StandardWebSocketSession                              │
│  • 管理连接状态                                                          │
│  • request(): 发送请求，等待响应                                         │
│  • notify(): 发送通知，无需响应                                          │
│  • _handleResponse(): 处理响应                                          │
│  • _handleNotification(): 处理通知                                       │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       StandardProtocolCodec                             │
│  • encodeRequest(): 编码请求/通知                                        │
│  • decode(): 解码服务器响应                                              │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    NativeTransport (WebSocket)                          │
│  • send(): 发送 JSON 消息                                                │
│  • 接收消息 → 解析 JSON → emit('message')                                │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Request 发送流程

Request 是一种需要等待服务器响应的消息发送方式。

### 2.1 调用链

```
ClientInstanceV2.request()
    │
    │  method: 'createRoom', payload: {...}, metadata: {...}
    ▼
StandardWebSocketSession.request()
    │
    ├── 1. 生成 requestId (时间戳 + deviceId + 8位随机数)
    │
    ├── 2. codec.encodeRequest() 编码
    │
    ├── 3. _pendingRequests[requestId] = completer 保存待处理请求
    │
    ├── 4. _transport.send(request) 发送
    │
    └── 5. 等待响应
            │
            ▼ 超时/响应
_handleResponse() → completer.complete()
    │
    ▼ 返回给调用者
ClientInstanceV2 收到 response
```

### 2.2 编码示例

**输入**:
```dart
_mainSession!.request(
  method: 'createRoom',
  payload: {"roomId": "room001", "peerName": "user1"},
  metadata: {'messageType': 'createRoom'}
);
```

**编码后的 JSON**:
```json
{
  "request": true,
  "method": "createRoom",
  "requestId": "1709283742000abc12345678",
  "messageType": "createRoom",
  "callType": 0,
  "data": {"roomId": "room001", "peerName": "user1"},
  "deviceId": "device_001",
  "peerId": "peer_001",
  "sessionId": "session_001",
  "deviceType": 1,
  "enableLLM": false,
  "transportType": "webrtc",
  "greyFlag": true,
  "isDigital": 1,
  "requestnum": 1
}
```

### 2.3 关键特性

- **重试机制**: 默认最多 3 次重试 (`maxRetries`)
- **超时处理**: 默认 8 秒超时 (`timeout`)
- **请求缓存**: 通过 `_pendingRequests` Map 管理待响应请求

---

## 3. Notify 发送流程

Notify 是一种无需等待服务器响应的消息发送方式。

### 3.1 调用链

```
ClientInstanceV2.notify() / letRobotSaySth()
    │
    ▼
StandardWebSocketSession.notify()
    │
    ├── 1. codec.encodeRequest() 编码 (无 requestId)
    │
    ├── 2. _transport.send(notification)
    │
    └── 3. 直接返回 (无等待)
```

### 3.2 编码示例

**输入**:
```dart
_mainSession!.notify(
  method: 'deliverMsg',
  payload: {'action': 'TEXT_RENDER', 'content': 'Hello'},
  metadata: {'messageType': 'deliverMsg'}
);
```

**编码后的 JSON**:
```json
{
  "request": true,
  "method": "deliverMsg",
  "messageType": "deliverMsg",
  "data": {"action": "TEXT_RENDER", "content": "Hello"},
  ...
}
```

> 注意: notify 也带有 `request: true` 标志，但不会生成 requestId。

---

## 4. 服务器响应处理流程

### 4.1 接收流程

```
服务器发送响应
    │
    ▼
NativeTransport 接收 (WebSocket.onMessage)
    │
    ├── 1. 解析 JSON: json.decode(event)
    │
    ├── 2. 字段修复 (临时方案):
    │       parsed['response'] = true
    │       parsed['responseId'] = parsed['requestId']
    │       parsed['success'] = true
    │
    ├── 3. emit('message', parsed)
    │
    ▼
StandardWebSocketSession
    │
    ▼
MessagePipeline.process()
    │
    ├── codec.decode() 解析消息类型
    │
    ├── 根据类型分发:
    │       ├── response → _handleResponse()
    │       ├── notification → _handleNotification()
    │       ├── request → _handleRequest()
    │       ├── event → _handleEvent()
    │       └── heartbeat → _handleHeartbeat()
    │
    ▼
处理完成
```

### 4.2 Response 处理详解

```dart
void _handleResponse(ParsedMessage message) {
  final requestId = message.requestId;
  
  // 1. 找到对应的 completer
  final completer = _pendingRequests.remove(requestId);
  
  if (completer == null) {
    loggerManager.warning('No pending request for id: $requestId');
    return;
  }

  // 2. 判断成功/失败
  if (message.success == true) {
    // 返回成功响应
    completer.complete({
      'success': true,
      'data': message.data,
    });
  } else {
    // 返回失败
    completer.completeError(Exception(
      'Request failed: ${message.errorCode} - ${message.errorMessage}'
    ));
  }
}
```

### 4.3 返回格式

**成功**:
```dart
{'success': true, 'data': {'roomId': 'room001', ...}}
```

**失败**:
```dart
Exception: Request failed: 500 - Error message
```

---

## 5. 协议编解码 (StandardProtocolCodec)

### 5.1 报文格式识别

| 条件 | 消息类型 |
|------|----------|
| `message['event'] == 'pong'` | heartbeat |
| `message['request'] == true` | request |
| `message['response'] == true` 或 `responseId != null` | response |
| `message['notification'] == true` | notification |
| `messageType == 'intention'` 且有 method | notification (服务器推送) |

### 5.2 编码字段说明

| 字段 | 说明 |
|------|------|
| `request` | 请求标志，notify 和 request 都为 true |
| `method` | 方法名 |
| `requestId` | 请求唯一ID (request 专用) |
| `messageType` | 消息类型，可从 metadata 获取或推断 |
| `callType` | 调用类型，根据 roomMode 确定 |
| `data` | 负载数据 |
| `deviceId` | 设备ID |
| `peerId` | 用户ID |
| `sessionId` | 会话ID |
| `deviceType` | 设备类型 |
| `enableLLM` | 是否启用 LLM |
| `transportType` | 传输类型 (webrtc) |

### 5.3 数据提取 (_extractData)

支持多种 data 格式:

1. **Map 对象**: 直接返回
2. **JSON 字符串**: 解析后返回
3. **嵌套响应**: 递归提取内层 data

```dart
// 嵌套响应示例
{
  "response": true,
  "id": "xxx",
  "data": {
    "response": true,
    "id": "yyy",
    "data": {"actualData": "..."}
  }
}
// 最终提取: {"actualData": "..."}
```

---

## 6. NativeTransport 详解

### 6.1 发送 (send)

```dart
Future send(message) async {
  // 1. 心跳消息直接发送字符串
  if (message is String && (message == "ping" || message == "pong")) {
    _ws?.add(message);
    return;
  }

  // 2. 普通消息 JSON 编码
  final encodableMessage = _makeEncodable(message);  // 处理 Set/Map/List
  final encodedMessage = jsonEncode(encodableMessage);
  
  // 3. WebSocket 发送
  _ws?.add(encodedMessage);
  
  // 4. 日志 (超过800字符分片输出)
}
```

### 6.2 接收 (_runWebSocket)

接收流程是整个通信链路中最复杂的部分，涉及消息解析和**字段修复的临时处理**。

#### 6.2.1 完整代码流程

```dart
ws.listen((event) {
  // ========== 步骤1: 心跳消息处理 ==========
  // 处理纯字符串心跳消息（"pong" / "ping"）
  if (event is String && (event == "pong" || event == "ping")) {
    this.safeEmit('message', {"event": event});
    return;
  }

  // ========== 步骤2: JSON 解析 ==========
  _logger.debug('V2: received raw data：$event');

  try {
    if (event is String) {
      // 解析 JSON 字符串为 Map
      final parsed = json.decode(event);
      if (parsed is Map) {
        // ========== 步骤3: 字段修复 (临时方案) ==========
        // 报文格式问题，临时修复方案
        parsed['response'] = true;
        parsed['responseId'] = parsed['requestId'];
        parsed['success'] = true;
        
        // ========== 步骤4: 发出消息事件 ==========
        this.safeEmit('message', Map<String, dynamic>.from(parsed));
      }
    } else if (event is Map) {
      // 如果已经是 Map，转换类型后发出
      // 报文格式问题，临时修复方案
      event['response'] = true;
      event['responseId'] = event['requestId'];
      event['success'] = true;
      this.safeEmit('message', Map<String, dynamic>.from(event));
    }
  } catch (e) {
    _logger.error('V2: Failed to parse JSON message: $e');
  }
});
```

#### 6.2.2 字段修复详解

**问题背景**:

服务器返回的响应报文可能缺少某些关键字段，导致 `StandardProtocolCodec.decode()` 无法正确识别消息类型。具体问题：

1. **缺少 `response` 标志**: 服务器响应可能只有 `requestId`，没有 `response: true`
2. **缺少 `responseId`**: 服务器可能返回 `requestId` 作为响应ID，而非 `responseId`
3. **缺少 `success` 标志**: 无法判断请求是否成功

**修复方案**:

在 NativeTransport 层面，在 JSON 解析后自动补充以下字段：

```dart
// 对于 String 解析后的 Map 或 已经是 Map 的情况
parsed['response'] = true;           // 标记为响应消息
parsed['responseId'] = parsed['requestId'];  // 复制 requestId 到 responseId
parsed['success'] = true;             // 默认标记为成功
```

**修复前后对比**:

| 字段 | 修复前 (服务器返回) | 修复后 (客户端处理) |
|------|---------------------|---------------------|
| `response` | 无 | `true` |
| `responseId` | 无 (只有 `requestId`) | `requestId` 的值 |
| `success` | 无 | `true` |

**示例**:

```json
// 服务器返回 (原始)
{
  "requestId": "1709283742000abc12345678",
  "method": "createRoom",
  "data": {"roomId": "room001"}
}

// NativeTransport 处理后
{
  "requestId": "1709283742000abc12345678",
  "method": "createRoom",
  "data": {"roomId": "room001"},
  "response": true,                              // 新增
  "responseId": "1709283742000abc12345678",       // 从 requestId 复制
  "success": true                                 // 新增
}
```

#### 6.2.3 处理分支

接收消息有两种可能的数据类型：

| 分支 | 条件 | 处理 |
|------|------|------|
| String 分支 | `event is String` | JSON 解析 → 字段修复 → emit |
| Map 分支 | `event is Map` | 直接字段修复 → emit |

#### 6.2.4 异常处理

```dart
try {
  // 解析和处理逻辑
} catch (e) {
  _logger.error('V2: Failed to parse JSON message: $e');
  // 不抛出异常，避免断开连接
}
```

> 注意: 解析失败时只记录日志，不抛出异常，以避免因单条消息解析失败而导致整个连接断开。

### 6.3 代理支持

NativeTransport 支持 HTTP 代理配置:

```dart
if (_proxyConfig != null) {
  customClient.findProxy = (uri) {
    return 'PROXY ${proxyHost}:${proxyPort}';
  };
  customClient.badCertificateCallback = (cert, host, port) => true;
}
```

---

## 7. protocol/ 目录结构

| 文件 | 作用 |
|------|------|
| `protocol_codec.dart` | 接口定义 (`IProtocolCodec`) 和 `ParsedMessage` 类 |
| `protocol.dart` | 导出文件 |
| `standard_protocol_codec.dart` | 标准协议编解码器 (用于主 WebSocket) |
| `mgw_protocol_codec.dart` | MGW 协议编解码器 (用于坐席连接) |
| `codec_factory.dart` | 编解码器工厂 |

---

## 8. 关键类说明

| 类 | 位置 | 作用 |
|----|------|------|
| `Transport` | `NativeTransport.dart` | WebSocket 封装 |
| `StandardWebSocketSession` | `websocket_session.dart` | 会话管理 |
| `StandardProtocolCodec` | `standard_protocol_codec.dart` | 协议编解码 |
| `MessagePipeline` | `pipeline.dart` | 消息分发管道 |
| `ParsedMessage` | `protocol_codec.dart` | 解析后的消息 |

---

## 9. ClientInstanceV2 使用示例

| 方法 | 调用方式 | 用途 |
|------|---------|------|
| `createRoom()` | `_mainSession!.request()` | 创建房间 (等待响应) |
| `joinRoom()` | `_mainSession!.request()` | 加入房间 (等待响应) |
| `letRobotSaySth()` | `_mainSession!.notify()` | 让机器人说话 (无需响应) |
| `leaveRoom()` | `_mainSession!.notify()` | 离开房间 (无需响应) |
| `sendEntranceTextMessage()` | `_mainSession!.request()` | 发送消息给Agent (等待响应) |
