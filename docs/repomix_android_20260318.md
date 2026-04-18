This file is a merged representation of the entire codebase, combined into a single document by Repomix.
The content has been processed where content has been formatted for parsing in markdown style.

# File Summary

## Purpose
This file contains a packed representation of the entire repository's contents.
It is designed to be easily consumable by AI systems for analysis, code review,
or other automated processes.

## File Format
The content is organized as follows:
1. This summary section
2. Repository information
3. Directory structure
4. Repository files (if enabled)
5. Multiple file entries, each consisting of:
  a. A header with the file path (## File: path/to/file)
  b. The full contents of the file in a code block

## Usage Guidelines
- This file should be treated as read-only. Any changes should be made to the
  original repository files, not this packed version.
- When processing this file, use the file path to distinguish
  between different files in the repository.
- Be aware that this file may contain sensitive information. Handle it with
  the same level of security as you would the original repository.

## Notes
- Some files may have been excluded based on .gitignore rules and Repomix's configuration
- Binary files are not included in this packed representation. Please refer to the Repository Structure section for a complete list of file paths, including binary files
- Files matching patterns in .gitignore are excluded
- Files matching default ignore patterns are excluded
- Content has been formatted for parsing in markdown style
- Files are sorted by Git change count (files with more changes are at the bottom)

# Directory Structure
```
app/
  .settings/
    org.eclipse.buildship.core.prefs
  src/
    androidTest/
      java/
        com/
          example/
            myapplicationforflutter/
              XChatKitSafetyTest.java
    main/
      java/
        com/
          example/
            myapplicationforflutter/
              ControlPanelController.java
              FloatingService.java
              LogManager.java
              MainActivity.java
      res/
        drawable/
          ic_launcher_background.xml
          ic_launcher_foreground.xml
        mipmap-anydpi/
          ic_launcher_round.xml
          ic_launcher.xml
        mipmap-hdpi/
          ic_launcher_round.webp
          ic_launcher.webp
        mipmap-mdpi/
          ic_launcher_round.webp
          ic_launcher.webp
        mipmap-xhdpi/
          ic_launcher_round.webp
          ic_launcher.webp
        mipmap-xxhdpi/
          ic_launcher_round.webp
          ic_launcher.webp
        mipmap-xxxhdpi/
          ic_launcher_round.webp
          ic_launcher.webp
        values/
          colors.xml
          strings.xml
          themes.xml
        values-night/
          themes.xml
        xml/
          backup_rules.xml
          data_extraction_rules.xml
      AndroidManifest.xml
    test/
      java/
        com/
          example/
            myapplicationforflutter/
              ExampleUnitTest.java
  .gitignore
  .project
  build.gradle
  proguard-rules.pro
gradle/
  wrapper/
    gradle-wrapper.jar
    gradle-wrapper.properties
  libs.versions.toml
lib/
  provider_sdk.jar
rsc-sdk/
  .settings/
    org.eclipse.buildship.core.prefs
  src/
    androidTest/
      java/
        com/
          yc/
            rtc/
              rsc_sdk/
                ExampleInstrumentedTest.java
    main/
      assets/
        xchatkit_config_debug.json
        xchatkit_config.json
      java/
        com/
          yc/
            rtc/
              rsc_sdk/
                ConferenceOptions.java
                FlutterDemoActivity.java
                PipMethodChannelHandler.java
                SDLActivityAdapter.java
                UserData.java
                XChatKit.java
                XChatKitConfig.java
                XChatLifecycleObserver.java
      AndroidManifest.xml
    test/
      java/
        com/
          yc/
            rtc/
              rsc_sdk/
                ExampleUnitTest.java
  .gitignore
  .project
  build.gradle
  consumer-rules.pro
  INTEGRATION_GUIDE.md
  proguard-rules.pro
.gitignore
build.gradle
gradle.properties
gradlew
gradlew.bat
settings.gradle
```

# Files

## File: app/.settings/org.eclipse.buildship.core.prefs
````
arguments=--init-script /Users/wangxinran/.local/share/opencode/bin/jdtls/config_mac/org.eclipse.osgi/59/0/.cp/gradle/init/init.gradle
auto.sync=false
build.scans.enabled=false
connection.gradle.distribution=GRADLE_DISTRIBUTION(VERSION(8.9))
connection.project.dir=
eclipse.preferences.version=1
gradle.user.home=
java.home=/Users/wangxinran/Library/Java/JavaVirtualMachines/corretto-11.0.22/Contents/Home
jvm.arguments=
offline.mode=false
override.workspace.settings=true
show.console.view=true
show.executions.view=true
````

## File: app/src/androidTest/java/com/example/myapplicationforflutter/XChatKitSafetyTest.java
````java
package com.example.myapplicationforflutter;

import android.content.Context;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.yc.rtc.rsc_sdk.XChatKit;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import static org.junit.Assert.*;

/**
 * XChatKit Safety Improvements 单元测试
 * 
 * 测试内容：
 * 1. 重复 init() 警告
 * 2. startConference() 未初始化时抛出 IllegalStateException
 * 3. addEventListener() 未初始化时警告
 * 4. 监听器重复添加警告
 */
@RunWith(AndroidJUnit4.class)
public class XChatKitSafetyTest {

    private Context context;

    @Before
    public void setUp() {
        context = InstrumentationRegistry.getInstrumentation().getTargetContext();
    }

    /**
     * 测试 1: 重复调用 init() 应该被检测到
     * 
     * 预期：第二次调用不会重复初始化，只会有警告日志
     */
    @Test
    public void testDuplicateInit() {
        // 第一次初始化
        XChatKit.init(context);
        
        // 第二次初始化 - 应该被检测到并输出警告
        // 注意：在测试中我们无法直接验证日志输出，但可以验证不会崩溃
        XChatKit.init(context);
        
        // 清理
        XChatKit.destroy();
    }

    /**
     * 测试: 未初始化状态下的行为
     * 注意: startConference() 需要真实 Activity，无法在单元测试中验证
     * 手动测试时，未初始化调用 startConference 会抛出 IllegalStateException
     */
    @Test
    public void testUninitializedBehavior() {
        // 确保未初始化
        XChatKit.destroy();
        
        // 验证：未初始化时 addEventListener 会输出警告（不会崩溃）
        XChatKit.XChatEventListener testListener = new TestXChatEventListener();
        XChatKit.addEventListener(testListener);
        
        // 验证：重复 init 会输出警告（不会崩溃）
        XChatKit.init(context);
        XChatKit.init(context); // 应该输出警告
        
        XChatKit.destroy();
    }

    /**
     * 测试 3: 未初始化时调用 addEventListener() 应该有警告
     * 
     * 预期：不会崩溃，监听器被添加（虽然 SDK 未初始化）
     */
    @Test
    public void testAddEventListenerWithoutInit() {
        // 确保未初始化
        XChatKit.destroy();
        
        // 添加监听器 - 应该有警告但不会崩溃
        XChatKit.XChatEventListener testListener = new TestXChatEventListener();
        XChatKit.addEventListener(testListener);
        
        // 清理
        XChatKit.removeEventListener(testListener);
    }

    /**
     * 测试 4: 重复添加同类型监听器应该被检测到
     * 
     * 预期：第二次添加同类型监听器时会有警告
     */
    @Test
    public void testDuplicateListener() {
        // 初始化
        XChatKit.init(context);
        
        // 创建相同类型的监听器（使用同一个类）
        XChatKit.XChatEventListener listener1 = new TestXChatEventListener();
        XChatKit.XChatEventListener listener2 = new TestXChatEventListener();
        
        // 添加第一个监听器
        XChatKit.addEventListener(listener1);
        
        // 添加同类型的第二个监听器 - 应该有警告
        // 因为两个都是 TestXChatEventListener 类
        XChatKit.addEventListener(listener2);
        
        // 清理
        XChatKit.destroy();
    }

    /**
     * 测试 5: 正常初始化和销毁流程
     * 
     * 预期：正常初始化和销毁，不抛出异常
     */
    @Test
    public void testNormalInitAndDestroy() {
        // 初始化
        XChatKit.init(context);
        
        // 添加监听器
        XChatKit.XChatEventListener testListener = new TestXChatEventListener();
        XChatKit.addEventListener(testListener);
        
        // 销毁
        XChatKit.destroy();
        
        // 验证可以重新初始化
        XChatKit.init(context);
        XChatKit.destroy();
    }
    
    /**
     * 测试用监听器类（用于测试重复添加）
     */
    private static class TestXChatEventListener implements XChatKit.XChatEventListener {
        @Override
        public void onMessage(String msgType, String message, String time) {
            // 空实现
        }
    }
}
````

## File: app/src/main/java/com/example/myapplicationforflutter/ControlPanelController.java
````java
package com.example.myapplicationforflutter;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import com.yc.rtc.rsc_sdk.XChatKit;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * 控制面板控制器：已增加清空日志功能
 */
public class ControlPanelController {
    private final Context context;
    private final boolean isFloating;
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm:ss", Locale.getDefault());
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private TextView tvLog;
    private ScrollView mainScrollView;
    private ImageView ivPhoto;
    private TextView tvBusinessPhotoPath;
    private Button btnStartBusinessPhoto;
    private Button btnStopBusinessPhoto;
    private Button btnBusinessPhotoForGroup;
    private Button btnBusinessPhotoForSingle;
    private Button btnPhoto;
    private Button btnClearLogs; // 新增：清空日志按钮
    private Button btnSendMessage; // 新增：发送消息按钮
    private Button btnStartConference; // 新增：启动会议按钮
    private View dragHandle;

    private static boolean sWebcamEnabled = false;

    public interface InteractionListener {
        void onStartConference();
        void onStopConference();
        void onMinimize();
    }

    private InteractionListener interactionListener;

    public ControlPanelController(Context context, boolean isFloating) {
        this.context = context;
        this.isFloating = isFloating;
    }

    public void setInteractionListener(InteractionListener listener) {
        this.interactionListener = listener;
    }

    public View getDragHandle() {
        return dragHandle;
    }

    public View createView() {
        LinearLayout rootLayout = new LinearLayout(context);
        rootLayout.setOrientation(LinearLayout.VERTICAL);
        rootLayout.setPadding(10, 10, 10, 10);
        rootLayout.setBackgroundColor(isFloating ? 0xEEFFFFFF : Color.WHITE);

        LinearLayout topBar = new LinearLayout(context);
        topBar.setOrientation(LinearLayout.HORIZONTAL);
        topBar.setGravity(Gravity.CENTER_VERTICAL);
        
        dragHandle = new TextView(context);
        ((TextView)dragHandle).setText(isFloating ? "⠿ 拖动手柄" : "控制面板");
        ((TextView)dragHandle).setGravity(Gravity.CENTER);
        ((TextView)dragHandle).setBackgroundColor(0xFFDDDDDD);
        ((TextView)dragHandle).setTextColor(Color.BLACK);
        LinearLayout.LayoutParams dragParams = new LinearLayout.LayoutParams(0, 90);
        dragParams.weight = 1;
        topBar.addView(dragHandle, dragParams);

        if (isFloating) {
            Button btnMinimize = new Button(context);
            btnMinimize.setText("➖");
            btnMinimize.setOnClickListener(v -> {
                if (interactionListener != null) interactionListener.onMinimize();
            });
            topBar.addView(btnMinimize, new LinearLayout.LayoutParams(120, 90));
        }
        rootLayout.addView(topBar);

        mainScrollView = new ScrollView(context);
        LinearLayout.LayoutParams scrollParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0);
        scrollParams.weight = 1;
        rootLayout.addView(mainScrollView, scrollParams);

        LinearLayout scrollContent = new LinearLayout(context);
        scrollContent.setOrientation(LinearLayout.VERTICAL);
        scrollContent.setPadding(10, 20, 10, 20);
        scrollContent.setGravity(Gravity.CENTER_HORIZONTAL);
        mainScrollView.addView(scrollContent);

        Switch switchEnv = new Switch(context);
        switchEnv.setText("测试环境");
        switchEnv.setChecked(XChatKit.getEnvironment() == XChatKit.ENV_DEBUG);
        switchEnv.setOnCheckedChangeListener((buttonView, isChecked) -> {
            int env = isChecked ? XChatKit.ENV_DEBUG : XChatKit.ENV_PROD;
            XChatKit.setEnvironment(env);
            appendLog("环境切换: " + (isChecked ? "测试" : "生产"));
        });
        scrollContent.addView(switchEnv);

        Button btnStart = new Button(context);
        btnStart.setText(isFloating ? "会议运行中" : "启动会议");
        btnStart.setEnabled(!isFloating);
        btnStart.setOnClickListener(v -> {
            if (interactionListener != null) interactionListener.onStartConference();
        });
        scrollContent.addView(btnStart);
        btnStartConference = btnStart;

        btnPhoto = new Button(context);
        btnPhoto.setText("📸 拍照");
        btnPhoto.setOnClickListener(v -> doTakePhoto());
        scrollContent.addView(btnPhoto);

//        btnStartBusinessPhoto = new Button(context);
//        btnStartBusinessPhoto.setText("开启业务拍照(旧)");
//        btnStartBusinessPhoto.setOnClickListener(v -> XChatKit.startBusinessPhotoMode());
//        scrollContent.addView(btnStartBusinessPhoto);
//
//        btnStopBusinessPhoto = new Button(context);
//        btnStopBusinessPhoto.setText("关闭业务拍照(旧)");
//        btnStopBusinessPhoto.setOnClickListener(v -> XChatKit.stopBusinessPhotoMode());
//        scrollContent.addView(btnStopBusinessPhoto);

        btnBusinessPhotoForGroup = new Button(context);
        btnBusinessPhotoForGroup.setText("合照模式");
        btnBusinessPhotoForGroup.setOnClickListener(v -> {
            String fileName = "group_photo_" + System.currentTimeMillis();
            XChatKit.businessPhotoForGroup(fileName, new XChatKit.OnBusinessPhotoTakeListener() {
                @Override
                public void onPhotoTakeSuccess(String filePath) {
                    appendLog("合照成功: " + filePath);
                    showBusinessPhotoPath(filePath);
                }

                @Override
                public void onPhotoTakeFail() {
                    appendLog("合照失败");
                }

                @Override
                public void onPhotoApiSuccess(java.util.List<String> filePaths) {
                    appendLog("API回调成功, filePaths size: " + (filePaths != null ? filePaths.size() : 0));
                    if (filePaths != null && filePaths.size() >= 3) {
                        String clientImagePath = null;
                        for (String path : filePaths) {
                            appendLog("API文件路径: " + path);
                            if (path != null && path.contains("_client.jpg")) {
                                clientImagePath = path;
                            }
                        }
                        if (clientImagePath != null) {
                            appendLog("展示_client.jpg: " + clientImagePath);
                            showBusinessPhotoPath(clientImagePath);
                        }
                    }
                }

                @Override
                public void onPhotoApiFail(String errorMessage) {
                    appendLog("API回调失败: " + errorMessage);
                }
            });
        });
        scrollContent.addView(btnBusinessPhotoForGroup);

        btnBusinessPhotoForSingle = new Button(context);
        btnBusinessPhotoForSingle.setText("单人照模式");
        btnBusinessPhotoForSingle.setOnClickListener(v -> {
            String fileName = "single_photo_" + System.currentTimeMillis();
            XChatKit.businessPhotoForSingle(fileName, true, "请面向摄像头", new XChatKit.OnBusinessPhotoTakeListener() {
                @Override
                public void onPhotoTakeSuccess(String filePath) {
                    appendLog("单人照成功: " + filePath);
                    showBusinessPhotoPath(filePath);
                }

                @Override
                public void onPhotoTakeFail() {
                    appendLog("单人照失败");
                }

                @Override
                public void onPhotoApiSuccess(java.util.List<String> filePaths) {
                    appendLog("单人照API回调成功: " + (filePaths != null ? filePaths.size() : 0));
                }

                @Override
                public void onPhotoApiFail(String errorMessage) {
                    appendLog("单人照API回调失败: " + errorMessage);
                }
            });
        });
        scrollContent.addView(btnBusinessPhotoForSingle);

        // 新增：发送消息按钮
        btnSendMessage = new Button(context);
        btnSendMessage.setText("📤 发送消息");
        btnSendMessage.setOnClickListener(v -> {
            String testMessage = "{\"authorId\":\"HF-XC4498870240240813153536361\",\"authorLevel\":\"1\",\"previousClerkId\":\"\",\"fileId\":\"131263B2075Q\",\"authorType\":\"B\",\"faceFlag\":\"2\",\"byOpeSys\":\"99700320000\"}";
            appendLog("发送消息: " + testMessage);
            XChatKit.sendMessage(testMessage);
        });
        scrollContent.addView(btnSendMessage);

        Button btnStop = new Button(context);
        btnStop.setText("🛑 停止会议");
        btnStop.setOnClickListener(v -> {
            mainHandler.post(() -> {
                if (interactionListener != null) interactionListener.onStopConference();
                XChatKit.stopConference();
                hidePhotoButtons();
            });
        });
        scrollContent.addView(btnStop);

        // 新增：清空日志按钮
        btnClearLogs = new Button(context);
        btnClearLogs.setText("🗑 清空日志面板");
        btnClearLogs.setOnClickListener(v -> clearLogs());
        // 浮窗模式下默认隐藏，非浮窗模式下默认显示（因为起始状态是停止状态）
        btnClearLogs.setVisibility(isFloating ? View.GONE : View.VISIBLE);
        scrollContent.addView(btnClearLogs);

        updateButtonVisibility(sWebcamEnabled);

        ivPhoto = new ImageView(context);
        ivPhoto.setMinimumHeight(300);
        ivPhoto.setBackgroundColor(Color.LTGRAY);
        LinearLayout.LayoutParams ivParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 400);
        ivParams.topMargin = 20;
        scrollContent.addView(ivPhoto, ivParams);

        tvBusinessPhotoPath = new TextView(context);
        tvBusinessPhotoPath.setPadding(10, 10, 10, 10);
        tvBusinessPhotoPath.setTextSize(12);
        tvBusinessPhotoPath.setTextColor(0xFF0066CC);
        tvBusinessPhotoPath.setText("业务拍照路径: ");
        tvBusinessPhotoPath.setVisibility(View.GONE);
        scrollContent.addView(tvBusinessPhotoPath);

        TextView logLabel = new TextView(context);
        logLabel.setText("\n回调日志:");
        logLabel.setTextSize(12);
        scrollContent.addView(logLabel);

        tvLog = new TextView(context);
        tvLog.setPadding(10, 10, 10, 10);
        tvLog.setTextSize(10);
        tvLog.setTextColor(0xFF333333);
        tvLog.setBackgroundColor(0xFFF5F5F5);
        scrollContent.addView(tvLog);
// 初始化日志
StringBuilder sb = new StringBuilder();
for (String log : LogManager.getLogs()) {
    sb.append(log).append("\n\n");
}
tvLog.setText(sb.toString());

        
        return rootLayout;
    }

    public void clearLogs() {
        LogManager.clear();
        mainHandler.post(() -> {
            if (tvLog != null) {
                tvLog.setText("");
            }
            Toast.makeText(context, "日志已清空", Toast.LENGTH_SHORT).show();
        });
    }

    public void updateClearButtonVisibility(boolean visible) {
        mainHandler.post(() -> {
            if (btnClearLogs != null && !isFloating) {
                btnClearLogs.setVisibility(visible ? View.VISIBLE : View.GONE);
            }
        });
    }

    public void setStartButtonEnabled(boolean enabled) {
        mainHandler.post(() -> {
            if (btnStartConference != null && !isFloating) {
                btnStartConference.setEnabled(enabled);
            }
        });
    }

    public void appendLog(String text) {
        String time = timeFormat.format(new Date());
        String fullLog = "[" + time + "] " + text;
        // 统一通过 LogManager 存入并分发，不再手动调用 updateLogUI
        LogManager.addLog(fullLog);
    }

    public void updateLogUI(String fullLog) {
        mainHandler.post(() -> {
            if (tvLog != null) {
                tvLog.append(fullLog + "\n\n");
            }
        });
    }

    public void updatePhoto(byte[] data) {
        if (data != null && data.length > 0) {
            Bitmap bmp = BitmapFactory.decodeByteArray(data, 0, data.length);
            mainHandler.post(() -> ivPhoto.setImageBitmap(bmp));
        }
    }

    public void showPhotoButtons() {
        sWebcamEnabled = true;
        updateButtonVisibility(true);
    }

    public void showBusinessPhotoPath(String filePath) {
        mainHandler.post(() -> {
            if (tvBusinessPhotoPath != null) {
                tvBusinessPhotoPath.setText("业务拍照路径: " + filePath);
                tvBusinessPhotoPath.setVisibility(View.VISIBLE);
            }
        });
    }

    public void hidePhotoButtons() {
        sWebcamEnabled = false;
        updateButtonVisibility(false);
    }

    private void updateButtonVisibility(boolean visible) {
        mainHandler.post(() -> {
            if (btnPhoto != null) {
                int visibility = visible ? View.VISIBLE : View.GONE;
                btnPhoto.setVisibility(visibility);
//                btnStartBusinessPhoto.setVisibility(visibility);
//                btnStopBusinessPhoto.setVisibility(visibility);
                btnBusinessPhotoForGroup.setVisibility(visibility);
                btnBusinessPhotoForSingle.setVisibility(visibility);
                if (btnSendMessage != null) {
                    btnSendMessage.setVisibility(visibility);
                }
            }
        });
    }

    private void doTakePhoto() {
        appendLog("正在请求拍照...");
        new Thread(() -> {
            byte[] data = XChatKit.takePhoto(null);
            if (data != null) {
                updatePhoto(data);
                appendLog("拍照成功: " + data.length + " bytes");
            }
        }).start();
    }
}
````

## File: app/src/main/java/com/example/myapplicationforflutter/FloatingService.java
````java
package com.example.myapplicationforflutter;

import android.app.Service;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.DisplayMetrics;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;

import androidx.annotation.Nullable;

import com.yc.rtc.rsc_sdk.XChatKit;

/**
 * 悬浮窗服务：适配新版 SDK 接口
 */
public class FloatingService extends Service {
    private WindowManager windowManager;
    private WindowManager.LayoutParams params;
    private View floatingView;
    private ControlPanelController controller;
    
    private boolean isMinimized = false;
    private int expandedWidth, expandedHeight;
    private int minimizedSize;

    private final XChatKit.XChatEventListener eventListener = new XChatKit.XChatEventListener() {
        @Override
        public void onMessage(String msgType, String message, String time) {
            // --- 调整：不再重复打印日志，仅处理业务逻辑 ---
            // controller.appendLog("【SDK 事件】" + msgType + "\n内容: " + message);
            
            if (XChatKit.EVENT_WEBCAM_ENABLED.equals(msgType)) {
                controller.showPhotoButtons();
            } else if (XChatKit.EVENT_WEBCAM_DISABLED.equals(msgType)) {
                controller.hidePhotoButtons();
            } else if (XChatKit.EVENT_CONFERENCE_STOPPED.equals(msgType) || XChatKit.EVENT_LEAVE_ROOM_DONE.equals(msgType)) {
                stopSelfWithReturn();
            }
        }

        @Override
        public void onReceiveMessage(String message) {
            controller.appendLog("【收到消息】" + message);
        }

        @Override
        public void onPhotoCaptured(byte[] data) {
            controller.updatePhoto(data);
            controller.appendLog("收到业务拍照图片: " + (data != null ? data.length : 0) + " bytes");
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        XChatKit.addEventListener(eventListener);
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        
        DisplayMetrics metrics = getResources().getDisplayMetrics();
        expandedWidth = (int) (metrics.widthPixels * 0.3);
        expandedHeight = (int) (metrics.heightPixels * 0.3);
        minimizedSize = (int) (80 * metrics.density);

        initFloatingView();

        LogManager.setListener(log -> controller.updateLogUI(log));
    }

    private void initFloatingView() {
        controller = new ControlPanelController(this, true);
        floatingView = controller.createView();

        controller.setInteractionListener(new ControlPanelController.InteractionListener() {
            @Override
            public void onStartConference() { }

            @Override
            public void onStopConference() {
                stopSelfWithReturn();
            }

            @Override
            public void onMinimize() {
                toggleMinimize();
            }
        });

        params = new WindowManager.LayoutParams(
                expandedWidth,
                expandedHeight,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O 
                    ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY 
                    : WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
        );

        params.gravity = Gravity.TOP | Gravity.START;
        params.x = 100;
        params.y = 100;

        View dragHandle = controller.getDragHandle();
        if (dragHandle != null) {
            dragHandle.setOnTouchListener(new View.OnTouchListener() {
                private int initialX;
                private int initialY;
                private float initialTouchX;
                private float initialTouchY;

                @Override
                public boolean onTouch(View v, MotionEvent event) {
                    switch (event.getAction()) {
                        case MotionEvent.ACTION_DOWN:
                            initialX = params.x;
                            initialY = params.y;
                            initialTouchX = event.getRawX();
                            initialTouchY = event.getRawY();
                            return true;
                        case MotionEvent.ACTION_MOVE:
                            params.x = initialX + (int) (event.getRawX() - initialTouchX);
                            params.y = initialY + (int) (event.getRawY() - initialTouchY);
                            windowManager.updateViewLayout(floatingView, params);
                            return true;
                    }
                    return false;
                }
            });
        }
        
        floatingView.setOnClickListener(v -> {
            if (isMinimized) toggleMinimize();
        });

        windowManager.addView(floatingView, params);
    }

    private void stopSelfWithReturn() {
        if (floatingView != null && floatingView.getParent() != null) {
            windowManager.removeView(floatingView);
            floatingView = null;
        }
        
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            Intent intent = new Intent(this, MainActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
            startActivity(intent);
            stopSelf();
        }, 50);
    }

    private void toggleMinimize() {
        isMinimized = !isMinimized;
        if (isMinimized) {
            params.width = (int)(minimizedSize * 1.5);
            params.height = minimizedSize;
            floatingView.setAlpha(0.6f);
        } else {
            params.width = expandedWidth;
            params.height = expandedHeight;
            floatingView.setAlpha(1.0f);
        }
        windowManager.updateViewLayout(floatingView, params);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (floatingView != null) windowManager.removeView(floatingView);
        XChatKit.removeEventListener(eventListener);
        LogManager.setListener(null);
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
````

## File: app/src/main/java/com/example/myapplicationforflutter/LogManager.java
````java
package com.example.myapplicationforflutter;

import java.util.ArrayList;
import java.util.List;

/**
 * 简单的全局日志管理器，用于在 Activity 和 Service 之间共享日志
 */
public class LogManager {
    private static final List<String> logList = new ArrayList<>();
    private static final int MAX_LOG_SIZE = 500; // 限制最大日志条数，防止 UI 渲染卡死
    private static LogListener listener;

    public interface LogListener {
        void onLogAdded(String log);
    }

    public static synchronized void addLog(String log) {
        if (logList.size() >= MAX_LOG_SIZE) {
            logList.remove(0);
        }
        logList.add(log);
        if (listener != null) {
            listener.onLogAdded(log);
        }
    }

    public static synchronized List<String> getLogs() {
        return new ArrayList<>(logList);
    }

    public static void setListener(LogListener l) {
        listener = l;
    }

    public static synchronized void clear() {
        logList.clear();
    }
}
````

## File: app/src/main/java/com/example/myapplicationforflutter/MainActivity.java
````java
package com.example.myapplicationforflutter;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Toast;

import androidx.annotation.Nullable;

import com.yc.rtc.rsc_sdk.ConferenceOptions;
import com.yc.rtc.rsc_sdk.XChatKit;

/**
 * 宿主 App 的主页 (演示 Demo) - 适配新版 SDK 接口
 */
public class MainActivity extends Activity {
    private static final int REQUEST_OVERLAY_PERMISSION = 1001;
    private ControlPanelController controller;

    private final XChatKit.XChatEventListener eventListener = new XChatKit.XChatEventListener() {
        @Override
        public void onMessage(String msgType, String message, String time) {
            controller.appendLog("【SDK 事件】" + msgType + "\n内容: " + message);
            if (XChatKit.EVENT_WEBCAM_ENABLED.equals(msgType)) {
                controller.showPhotoButtons();
            } else if (XChatKit.EVENT_WEBCAM_DISABLED.equals(msgType)) {
                controller.hidePhotoButtons();
            } else if (XChatKit.EVENT_CONFERENCE_STOPPED.equals(msgType)) {
                // 会议停止，显示清空日志按钮
                controller.updateClearButtonVisibility(true);
            } else if (XChatKit.EVENT_LEAVE_ROOM_DONE.equals(msgType)) {
                // 收到离会完成事件，仅记录日志，由 FloatingService 负责回收
                controller.appendLog("离会完成，流程结束");
            } else if (XChatKit.EVENT_MATCH_AGENT_DONE.equals(msgType)) {
                // 收到离会完成事件，仅记录日志，由 FloatingService 负责回收
                controller.appendLog("坐席匹配成功："+ message.toString());
            }
        }

        @Override
        public void onReceiveMessage(String message) {
            controller.appendLog("【收到消息】" + message);
        }

        @Override
        public void onPhotoCaptured(byte[] data) {
            controller.updatePhoto(data);
            controller.appendLog("收到业务拍照图片: " + (data != null ? data.length : 0) + " bytes");
        }
    };

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        controller = new ControlPanelController(this, false);
        setContentView(controller.createView());
        
        // 初始化 SDK 并监听引擎预热（仅记录日志，不影响按钮状态）
        long initStartTime = System.currentTimeMillis();
        XChatKit.init(getApplicationContext(), new XChatKit.OnEnginePrewarmListener() {
            @Override
            public void onEnginePrewarmComplete() {
                long duration = System.currentTimeMillis() - initStartTime;
                runOnUiThread(() -> {
                    controller.appendLog("Flutter 引擎预热完成, init 回调耗时: " + duration + "ms");
                });
            }

            @Override
            public void onEnginePrewarmFailed(String error) {
                runOnUiThread(() -> {
                    controller.appendLog("Flutter 引擎预热失败: " + error + "，将使用兜底引擎");
                });
            }
        });

        XChatKit.addEventListener(eventListener);

        controller.setInteractionListener(new ControlPanelController.InteractionListener() {
            @Override
            public void onStartConference() {
                checkPermissionAndStart();
            }

            @Override
            public void onStopConference() {
                controller.updateClearButtonVisibility(true);
            }

            @Override
            public void onMinimize() { }
        });

        LogManager.setListener(log -> controller.updateLogUI(log));
    }

    @Override
    protected void onResume() {
        super.onResume();
        // 1. 回到前台时，重新接管 SDK 监听
        XChatKit.addEventListener(eventListener);
        // 2. 重新夺回全局日志管理器的监听权，确保日志能显示在全屏面板上
        LogManager.setListener(log -> controller.updateLogUI(log));
    }

    private void checkPermissionAndStart() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:" + getPackageName()));
                startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION);
            } else {
                startConferenceWithFloating();
            }
        } else {
            startConferenceWithFloating();
        }
    }

    private void startConferenceWithFloating() {
        try {
            startService(new Intent(this, FloatingService.class));
            
            controller.updateClearButtonVisibility(false);

            // 使用新的 ConferenceOptions 构建参数（展示新的 API）
            ConferenceOptions options = new ConferenceOptions.Builder()
                    .setFromUser("862175051124177")
                    .setRoute("/room")
                    .setBrhName("中国邮政储蓄银行股份有限公司银川市金凤区支行")
                    .setLanguage("01")
                    .setLanguageName("普通话")
                    .setUnionId("64000652")
                    .clientInfo()
                        .setTellerCode("20080612010")
                        .setTellerName("某**")
                        .setTellerBranch("11009021")
                        .setTellerIdNo("510321197****1565X")
                        .setIp("172.20.10.7")
                        .setLocationFlag("1")
                        .setFileId("1312639206AK")
                        .setPageIndex(1)
                        .setPushSpeechFlag("1")
                        .setOutTaskNo("")
                        .deviceInfo()
                            .setImei("862175051124177")
                            .setBrand("HUAWEI")
                            .setModel("BZT3-AL00")
                            .setBoard("BZT3-AL00")
                            .setOsVersion("10")
                            .setSdk("29")
                            .setDisplay("2000x1200")
                            .setGps("")
                            .setBoxflag("")
                            .setBrhShtName("北**台区**支行")
                            .setDeviceInst("11009021")
                            .setDeviceNo("9999130008")
                            .setUpdeviceInst("11000013")
                            .build()  // 返回 DeviceInfoBuilder
                        .build()    // 返回 ClientInfoBuilder
                    .build();      // 返回 ConferenceOptions
            XChatKit.startConference(this, options);
            
            controller.appendLog("已启动会议");
            
        } catch (Exception e) {
            e.printStackTrace();
            controller.appendLog("启动失败: " + e.getMessage());
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_OVERLAY_PERMISSION) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                startConferenceWithFloating();
            } else {
                Toast.makeText(this, "未获得权限", Toast.LENGTH_SHORT).show();
                XChatKit.startConference(this); // 这里也可以改为使用 options，但暂且保持简单
                controller.updateClearButtonVisibility(false);
            }
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        XChatKit.removeEventListener(eventListener);
        LogManager.setListener(null);
        // 注意：这里我们不调用 destroy，因为悬浮窗可能还在运行。
        // 正确的做法应该是有个全局的 Service 管理生命周期，或者在 FloatingService 退出时判断。
    }
}
````

## File: app/src/main/res/drawable/ic_launcher_background.xml
````xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#3DDC84"
        android:pathData="M0,0h108v108h-108z" />
    <path
        android:fillColor="#00000000"
        android:pathData="M9,0L9,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M19,0L19,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M29,0L29,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M39,0L39,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M49,0L49,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M59,0L59,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M69,0L69,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M79,0L79,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M89,0L89,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M99,0L99,108"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,9L108,9"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,19L108,19"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,29L108,29"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,39L108,39"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,49L108,49"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,59L108,59"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,69L108,69"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,79L108,79"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,89L108,89"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M0,99L108,99"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M19,29L89,29"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M19,39L89,39"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M19,49L89,49"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M19,59L89,59"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M19,69L89,69"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M19,79L89,79"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M29,19L29,89"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M39,19L39,89"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M49,19L49,89"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M59,19L59,89"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M69,19L69,89"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
    <path
        android:fillColor="#00000000"
        android:pathData="M79,19L79,89"
        android:strokeWidth="0.8"
        android:strokeColor="#33FFFFFF" />
</vector>
````

## File: app/src/main/res/drawable/ic_launcher_foreground.xml
````xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:pathData="M31,63.928c0,0 6.4,-11 12.1,-13.1c7.2,-2.6 26,-1.4 26,-1.4l38.1,38.1L107,108.928l-32,-1L31,63.928z">
        <aapt:attr name="android:fillColor">
            <gradient
                android:endX="85.84757"
                android:endY="92.4963"
                android:startX="42.9492"
                android:startY="49.59793"
                android:type="linear">
                <item
                    android:color="#44000000"
                    android:offset="0.0" />
                <item
                    android:color="#00000000"
                    android:offset="1.0" />
            </gradient>
        </aapt:attr>
    </path>
    <path
        android:fillColor="#FFFFFF"
        android:fillType="nonZero"
        android:pathData="M65.3,45.828l3.8,-6.6c0.2,-0.4 0.1,-0.9 -0.3,-1.1c-0.4,-0.2 -0.9,-0.1 -1.1,0.3l-3.9,6.7c-6.3,-2.8 -13.4,-2.8 -19.7,0l-3.9,-6.7c-0.2,-0.4 -0.7,-0.5 -1.1,-0.3C38.8,38.328 38.7,38.828 38.9,39.228l3.8,6.6C36.2,49.428 31.7,56.028 31,63.928h46C76.3,56.028 71.8,49.428 65.3,45.828zM43.4,57.328c-0.8,0 -1.5,-0.5 -1.8,-1.2c-0.3,-0.7 -0.1,-1.5 0.4,-2.1c0.5,-0.5 1.4,-0.7 2.1,-0.4c0.7,0.3 1.2,1 1.2,1.8C45.3,56.528 44.5,57.328 43.4,57.328L43.4,57.328zM64.6,57.328c-0.8,0 -1.5,-0.5 -1.8,-1.2s-0.1,-1.5 0.4,-2.1c0.5,-0.5 1.4,-0.7 2.1,-0.4c0.7,0.3 1.2,1 1.2,1.8C66.5,56.528 65.6,57.328 64.6,57.328L64.6,57.328z"
        android:strokeWidth="1"
        android:strokeColor="#00000000" />
</vector>
````

## File: app/src/main/res/mipmap-anydpi/ic_launcher_round.xml
````xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
````

## File: app/src/main/res/mipmap-anydpi/ic_launcher.xml
````xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
````

## File: app/src/main/res/values/colors.xml
````xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="purple_200">#FFBB86FC</color>
    <color name="purple_500">#FF6200EE</color>
    <color name="purple_700">#FF3700B3</color>
    <color name="teal_200">#FF03DAC5</color>
    <color name="teal_700">#FF018786</color>
    <color name="black">#FF000000</color>
    <color name="white">#FFFFFFFF</color>
</resources>
````

## File: app/src/main/res/values/strings.xml
````xml
<resources>
    <string name="app_name">My Application For Flutter</string>
</resources>
````

## File: app/src/main/res/values/themes.xml
````xml
<resources xmlns:tools="http://schemas.android.com/tools">
    <!-- Base application theme. -->
    <style name="Theme.MyApplicationForFlutter" parent="Theme.MaterialComponents.DayNight.DarkActionBar">
        <!-- Primary brand color. -->
        <item name="colorPrimary">@color/purple_500</item>
        <item name="colorPrimaryVariant">@color/purple_700</item>
        <item name="colorOnPrimary">@color/white</item>
        <!-- Secondary brand color. -->
        <item name="colorSecondary">@color/teal_200</item>
        <item name="colorSecondaryVariant">@color/teal_700</item>
        <item name="colorOnSecondary">@color/black</item>
        <!-- Status bar color. -->
        <item name="android:statusBarColor">?attr/colorPrimaryVariant</item>
        <!-- Customize your theme here. -->
    </style>
</resources>
````

## File: app/src/main/res/values-night/themes.xml
````xml
<resources xmlns:tools="http://schemas.android.com/tools">
    <!-- Base application theme. -->
    <style name="Theme.MyApplicationForFlutter" parent="Theme.MaterialComponents.DayNight.DarkActionBar">
        <!-- Primary brand color. -->
        <item name="colorPrimary">@color/purple_200</item>
        <item name="colorPrimaryVariant">@color/purple_700</item>
        <item name="colorOnPrimary">@color/black</item>
        <!-- Secondary brand color. -->
        <item name="colorSecondary">@color/teal_200</item>
        <item name="colorSecondaryVariant">@color/teal_200</item>
        <item name="colorOnSecondary">@color/black</item>
        <!-- Status bar color. -->
        <item name="android:statusBarColor">?attr/colorPrimaryVariant</item>
        <!-- Customize your theme here. -->
    </style>
</resources>
````

## File: app/src/main/res/xml/backup_rules.xml
````xml
<?xml version="1.0" encoding="utf-8"?><!--
   Sample backup rules file; uncomment and customize as necessary.
   See https://developer.android.com/guide/topics/data/autobackup
   for details.
   Note: This file is ignored for devices older that API 31
   See https://developer.android.com/about/versions/12/backup-restore
-->
<full-backup-content>
    <!--
   <include domain="sharedpref" path="."/>
   <exclude domain="sharedpref" path="device.xml"/>
-->
</full-backup-content>
````

## File: app/src/main/res/xml/data_extraction_rules.xml
````xml
<?xml version="1.0" encoding="utf-8"?><!--
   Sample data extraction rules file; uncomment and customize as necessary.
   See https://developer.android.com/about/versions/12/backup-restore#xml-changes
   for details.
-->
<data-extraction-rules>
    <cloud-backup>
        <!-- TODO: Use <include> and <exclude> to control what is backed up.
        <include .../>
        <exclude .../>
        -->
    </cloud-backup>
    <!--
    <device-transfer>
        <include .../>
        <exclude .../>
    </device-transfer>
    -->
</data-extraction-rules>
````

## File: app/src/main/AndroidManifest.xml
````xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.Light.DarkActionBar"
        tools:targetApi="31">

        <!-- 宿主的主页 -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- 悬浮窗控制面板服务 -->
        <service android:name=".FloatingService"
            android:enabled="true"
            android:exported="false" />
    </application>
</manifest>
````

## File: app/src/test/java/com/example/myapplicationforflutter/ExampleUnitTest.java
````java
package com.example.myapplicationforflutter;

import org.junit.Test;

import static org.junit.Assert.*;

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
public class ExampleUnitTest {
    @Test
    public void addition_isCorrect() {
        assertEquals(4, 2 + 2);
    }
}
````

## File: app/.gitignore
````
/build
````

## File: app/.project
````
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
	<name>app</name>
	<comment>Project app created by Buildship.</comment>
	<projects>
	</projects>
	<buildSpec>
		<buildCommand>
			<name>org.eclipse.buildship.core.gradleprojectbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
	</buildSpec>
	<natures>
		<nature>org.eclipse.buildship.core.gradleprojectnature</nature>
	</natures>
	<filteredResources>
		<filter>
			<id>1773044247450</id>
			<name></name>
			<type>30</type>
			<matcher>
				<id>org.eclipse.core.resources.regexFilterMatcher</id>
				<arguments>node_modules|\.git|__CREATED_BY_JAVA_LANGUAGE_SERVER__</arguments>
			</matcher>
		</filter>
	</filteredResources>
</projectDescription>
````

## File: app/build.gradle
````
plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace 'com.example.myapplicationforflutter'
    compileSdk 35

    defaultConfig {
        applicationId "com.example.myapplicationforflutter"
        minSdk 29
        targetSdk 35
        versionCode 1
        versionName "1.0"

        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            signingConfig signingConfigs.debug
        }
        profile {
            initWith debug
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {

    implementation libs.appcompat
    implementation libs.material
    testImplementation libs.junit
    androidTestImplementation libs.ext.junit
    androidTestImplementation libs.espresso.core
    debugImplementation 'com.yc.rtc.flutter_module:flutter_debug:1.0'
    profileImplementation 'com.yc.rtc.flutter_module:flutter_profile:1.0'
    releaseImplementation 'com.yc.rtc.flutter_module:flutter_release:1.0'

    // 引入 SDK 模块
//    implementation project(':rsc-sdk')
    implementation 'com.yc.rtc:rtc-sdk:1.0.0'
}
````

## File: app/proguard-rules.pro
````
# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile
````

## File: gradle/wrapper/gradle-wrapper.properties
````
#Thu Dec 12 20:52:18 CST 2024
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.10.2-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
````

## File: gradle/libs.versions.toml
````toml
[versions]
agp = "8.6.1"
junit = "4.13.2"
junitVersion = "1.2.1"
espressoCore = "3.6.1"
appcompat = "1.7.0"
material = "1.12.0"

[libraries]
junit = { group = "junit", name = "junit", version.ref = "junit" }
ext-junit = { group = "androidx.test.ext", name = "junit", version.ref = "junitVersion" }
espresso-core = { group = "androidx.test.espresso", name = "espresso-core", version.ref = "espressoCore" }
appcompat = { group = "androidx.appcompat", name = "appcompat", version.ref = "appcompat" }
material = { group = "com.google.android.material", name = "material", version.ref = "material" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
````

## File: rsc-sdk/.settings/org.eclipse.buildship.core.prefs
````
arguments=--init-script /Users/wangxinran/.local/share/opencode/bin/jdtls/config_mac/org.eclipse.osgi/59/0/.cp/gradle/init/init.gradle
auto.sync=false
build.scans.enabled=false
connection.gradle.distribution=GRADLE_DISTRIBUTION(VERSION(8.9))
connection.project.dir=
eclipse.preferences.version=1
gradle.user.home=
java.home=/Users/wangxinran/Library/Java/JavaVirtualMachines/corretto-11.0.22/Contents/Home
jvm.arguments=
offline.mode=false
override.workspace.settings=true
show.console.view=true
show.executions.view=true
````

## File: rsc-sdk/src/androidTest/java/com/yc/rtc/rsc_sdk/ExampleInstrumentedTest.java
````java
package com.yc.rtc.rsc_sdk;

import android.content.Context;

import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;

import org.junit.Test;
import org.junit.runner.RunWith;

import static org.junit.Assert.*;

/**
 * Instrumented test, which will execute on an Android device.
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
@RunWith(AndroidJUnit4.class)
public class ExampleInstrumentedTest {
    @Test
    public void useAppContext() {
        // Context of the app under test.
        Context appContext = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assertEquals("com.yc.rtc.rsc_sdk.test", appContext.getPackageName());
    }
}
````

## File: rsc-sdk/src/main/assets/xchatkit_config_debug.json
````json
{
  "userData": {
    "appid": "webchat",
    "brhName": "中国邮政储蓄银行股份有限公司银川市金凤区支行",
    "browser": "pad",
    "busitype1": "ZY",
    "dept": "",
    "deviceId": "",
    "errorMessage": "",
    "exSessionid": "621465265415122462120511730386227606214591",
    "fromuser": "62146526541512246212051173038622",
    "init": 0,
    "language": "01",
    "languageName": "普通话",
    "noAgentLogin": 0,
    "p2p": "false",
    "queueHintCount": 0,
    "queueHintInterval": 0,
    "r_flag": -1,
    "readid": "02",
    "unionId": "64000652",
    "visitorSendInst": "99700320000",
    "clientInfo": {
      "fileId": "1312639206AK",
      "ip": "172.20.10.7",
      "locationFlag": "1",
      "pageIndex": 1,
      "pushSpeechFlag": "1",
      "tellerBranch": "11009021",
      "tellerCode": "20080612010",
      "tellerIdNo": "510321197****1565X",
      "tellerName": "某**",
      "deviceInfo": {
        "board": "BZT3-AL00",
        "boxflag": "",
        "brand": "HUAWEI",
        "brhShtName": "北**台区**支行",
        "deviceInst": "11009021",
        "deviceNo": "9999130008",
        "display": "2000x1200",
        "gps": "",
        "imei": "869097041962172",
        "model": "BZT3-AL00",
        "osVersion": "10",
        "sdk": "29",
        "updeviceInst": "11000013"
      }
    }
  },
  "mediaInfo": {
    "aCenter": "20.198.100.91:18090",
    "bCenter": "20.198.100.79:18090",
    "probe": "/probe",
    "mediaEntranceUrl": "/media-entrance/websocket",
    "mgwUrl": "/mgw",
    "picUrl": "/GATEWAY/operating/picture/ROP403",
    "roomMode": "single_pad",
    "roomId": "",
    "peerId": "44444481",
    "peerType": "",
    "iceServers": [
      {
        "urls": [
          "turn:20.198.100.91:3478",
          "turn:20.198.100.91:3479"
        ],
        "username": "test",
        "credential": "1234",
        "credentialType": "password"
      }
    ]
  }
}
````

## File: rsc-sdk/src/main/assets/xchatkit_config.json
````json
{
  "userData": {
    "appid": "webchat",
    "brhName": "中国邮政储蓄银行股份有限公司银川市金凤区支行",
    "browser": "pad",
    "busitype1": "ZY",
    "dept": "",
    "deviceId": "",
    "errorMessage": "",
    "exSessionid": "621465265415122462120511730386227606214591",
    "fromuser": "62146526541512246212051173038622",
    "init": 0,
    "language": "01",
    "languageName": "普通话",
    "noAgentLogin": 0,
    "p2p": "false",
    "queueHintCount": 0,
    "queueHintInterval": 0,
    "r_flag": -1,
    "readid": "02",
    "unionId": "64000652",
    "visitorSendInst": "99700320000",
    "clientInfo": {
      "fileId": "1312639206AK",
      "ip": "172.20.10.7",
      "locationFlag": "1",
      "pageIndex": 1,
      "pushSpeechFlag": "1",
      "tellerBranch": "11009021",
      "tellerCode": "20080612010",
      "tellerIdNo": "510321197****1565X",
      "tellerName": "某**",
      "deviceInfo": {
        "board": "BZT3-AL00",
        "boxflag": "",
        "brand": "HUAWEI",
        "brhShtName": "北**台区**支行",
        "deviceInst": "11009021",
        "deviceNo": "9999130008",
        "display": "2000x1200",
        "gps": "",
        "imei": "869097041962172",
        "model": "BZT3-AL00",
        "osVersion": "10",
        "sdk": "29",
        "updeviceInst": "11000013"
      }
    }
  },
  "mediaInfo": {
    "aCenter": "rsc.psbc.com:8052",
    "bCenter": "rsc.psbc.com:8052",
    "probe": "",
    "mediaEntranceUrl": "/gateway/media-entrance/websocket",
    "mgwUrl": "/gateway/mgw",
    "picUrl": "/gateway/GATEWAY/operating/picture/ROP403",
    "roomMode": "single_pad",
    "roomId": "",
    "peerId": "",
    "peerType": "",
    "iceServers": [
      {
        "urls": [
          "turn:rsc.psbc.com:13478",
          "turn:rsc.psbc.com:13479",
          "turn:rsc.psbc.com:13480"
        ],
        "username": "test",
        "credential": "1234",
        "credentialType": "password"
      }
    ]
  }
}
````

## File: rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/ConferenceOptions.java
````java
package com.yc.rtc.rsc_sdk;

import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

/**
 * 会议启动配置类 (Builder 模式)
 * 提供类型安全的参数设置与校验
 */
public class ConferenceOptions implements Serializable {
    private String route = "/";
    private final Map<String, Object> arguments = new HashMap<>();

    private ConferenceOptions() {}

    public static class Builder {
        private final ConferenceOptions options;
        private ClientInfoBuilder clientInfoBuilder;

        public Builder() {
            options = new ConferenceOptions();
            // 设置默认值
            options.arguments.put("appid", "");
            options.arguments.put("dept", "");
            options.arguments.put("channelName", "zypad");
            options.arguments.put("deviceId", "");
            options.arguments.put("init", 0);
            options.arguments.put("noAgentLogin", 0);
            options.arguments.put("p2p", false);
            options.arguments.put("queueHintCount", 0);
            options.arguments.put("queueHintInterval", 0);
            options.arguments.put("browser", "pad");
            options.arguments.put("busitype1", "ZY");
            options.arguments.put("visitorSendInst", "99700320000");
            options.arguments.put("r_flag", -1);
        }

        /**
         * 设置 Flutter 页面路由
         * @param route 例如 "/room", "/call"
         */
        public Builder setRoute(String route) {
            if (route != null && !route.isEmpty()) {
                options.route = route;
            }
            return this;
        }

        /**
         * 设置发起方用户 ID
         * @param userId 用户唯一标识
         */
        public Builder setFromUser(String userId) {
            if (userId == null || userId.isEmpty()) {
                throw new IllegalArgumentException("fromUser cannot be null or empty");
            }
            options.arguments.put("fromuser", userId);
            return this;
        }

        /**
         * 设置 brhName（行名称）
         * @param brhName 行名称
         */
        public Builder setBrhName(String brhName) {
            options.arguments.put("brhName", brhName);
            return this;
        }

        /**
         * 设置 unionId（联盟ID）
         * @param unionId 联盟ID
         */
        public Builder setUnionId(String unionId) {
            options.arguments.put("unionId", unionId);
            return this;
        }

        /**
         * 设置 deviceId（设备ID）
         * @param deviceId 设备ID
         */
        public Builder setDeviceId(String deviceId) {
            options.arguments.put("deviceId", deviceId);
            return this;
        }

        /**
         * 设置 language（语言代码）
         * @param language 语言代码，如 "01"
         */
        public Builder setLanguage(String language) {
            options.arguments.put("language", language);
            return this;
        }

        /**
         * 设置 languageName（语言名称）
         * @param languageName 语言名称，如 "普通话"
         */
        public Builder setLanguageName(String languageName) {
            options.arguments.put("languageName", languageName);
            return this;
        }

        /**
         * 获取 ClientInfoBuilder 用于设置 clientInfo 嵌套字段
         * @return ClientInfoBuilder 实例
         */
        public ClientInfoBuilder clientInfo() {
            if (clientInfoBuilder == null) {
                clientInfoBuilder = new ClientInfoBuilder(this, options.arguments);
            }
            return clientInfoBuilder;
        }

        // ==================== 便捷方法 ====================

        /**
         * 设置 tellerCode（柜员编号）
         * 便捷方法，内部调用 clientInfo().setTellerCode()
         */
        public ClientInfoBuilder setTellerCode(String tellerCode) {
            return clientInfo().setTellerCode(tellerCode);
        }

        /**
         * 设置 tellerName（柜员姓名）
         * 便捷方法，内部调用 clientInfo().setTellerName()
         */
        public ClientInfoBuilder setTellerName(String tellerName) {
            return clientInfo().setTellerName(tellerName);
        }

        /**
         * 设置 tellerBranch（柜员所属机构）
         * 便捷方法，内部调用 clientInfo().setTellerBranch()
         */
        public ClientInfoBuilder setTellerBranch(String tellerBranch) {
            return clientInfo().setTellerBranch(tellerBranch);
        }

        /**
         * 设置 tellerIdNo（柜员身份证号）
         * 便捷方法，内部调用 clientInfo().setTellerIdNo()
         */
        public ClientInfoBuilder setTellerIdNo(String tellerIdNo) {
            return clientInfo().setTellerIdNo(tellerIdNo);
        }

        /**
         * 设置 ip（IP地址）
         * 便捷方法，内部调用 clientInfo().setIp()
         */
        public ClientInfoBuilder setIp(String ip) {
            return clientInfo().setIp(ip);
        }

        /**
         * 设置 locationFlag（定位标识）
         * 便捷方法，内部调用 clientInfo().setLocationFlag()
         */
        public ClientInfoBuilder setLocationFlag(String locationFlag) {
            return clientInfo().setLocationFlag(locationFlag);
        }

        /**
         * 设置 fileId（文件ID）
         * 便捷方法，内部调用 clientInfo().setFileId()
         */
        public ClientInfoBuilder setFileId(String fileId) {
            return clientInfo().setFileId(fileId);
        }

        /**
         * 设置 pageIndex（页面索引）
         * 便捷方法，内部调用 clientInfo().setPageIndex()
         */
        public ClientInfoBuilder setPageIndex(int pageIndex) {
            return clientInfo().setPageIndex(pageIndex);
        }

        /**
         * 设置 pushSpeechFlag（语音推送标识）
         * 便捷方法，内部调用 clientInfo().setPushSpeechFlag()
         */
        public ClientInfoBuilder setPushSpeechFlag(String pushSpeechFlag) {
            return clientInfo().setPushSpeechFlag(pushSpeechFlag);
        }

        /**
         * 设置 outTaskNo（外拓任务编号）
         * 便捷方法，内部调用 clientInfo().setOutTaskNo()
         */
        public ClientInfoBuilder setOutTaskNo(String outTaskNo) {
            return clientInfo().setOutTaskNo(outTaskNo);
        }

        /**
         * 添加自定义参数
         */
        public Builder addArgument(String key, Object value) {
            options.arguments.put(key, value);
            return this;
        }

        /**
         * 构建配置对象
         */
        public ConferenceOptions build() {
            // 在这里可以进行更多的必填项校验
            return options;
        }
    }

    /**
     * ClientInfo 嵌套 Builder
     * 用于设置 clientInfo 对象中的字段
     */
    public static class ClientInfoBuilder {
        private final Builder parent;
        private final Map<String, Object> clientInfoMap;
        private DeviceInfoBuilder deviceInfoBuilder;

        ClientInfoBuilder(Builder parent, Map<String, Object> parentArgs) {
            this.parent = parent;
            this.clientInfoMap = new HashMap<>();
            parentArgs.put("clientInfo", clientInfoMap);
        }

        public ClientInfoBuilder setIp(String ip) {
            clientInfoMap.put("ip", ip);
            return this;
        }

        public ClientInfoBuilder setLocationFlag(String locationFlag) {
            clientInfoMap.put("locationFlag", locationFlag);
            return this;
        }

        public ClientInfoBuilder setFileId(String fileId) {
            clientInfoMap.put("fileId", fileId);
            return this;
        }

        public ClientInfoBuilder setPageIndex(int pageIndex) {
            clientInfoMap.put("pageIndex", pageIndex);
            return this;
        }

        public ClientInfoBuilder setPushSpeechFlag(String pushSpeechFlag) {
            clientInfoMap.put("pushSpeechFlag", pushSpeechFlag);
            return this;
        }

        public ClientInfoBuilder setTellerBranch(String tellerBranch) {
            clientInfoMap.put("tellerBranch", tellerBranch);
            return this;
        }

        public ClientInfoBuilder setTellerCode(String tellerCode) {
            clientInfoMap.put("tellerCode", tellerCode);
            return this;
        }

        public ClientInfoBuilder setTellerIdNo(String tellerIdNo) {
            clientInfoMap.put("tellerIdNo", tellerIdNo);
            return this;
        }

        public ClientInfoBuilder setTellerName(String tellerName) {
            clientInfoMap.put("tellerName", tellerName);
            return this;
        }

        public ClientInfoBuilder setOutTaskNo(String outTaskNo) {
            clientInfoMap.put("outTaskNo", outTaskNo);
            return this;
        }

        /**
         * 获取 DeviceInfoBuilder 用于设置 deviceInfo 嵌套字段
         * @return DeviceInfoBuilder 实例
         */
        public DeviceInfoBuilder deviceInfo() {
            if (deviceInfoBuilder == null) {
                deviceInfoBuilder = new DeviceInfoBuilder(this, clientInfoMap);
            }
            return deviceInfoBuilder;
        }

        /**
         * 返回父 Builder
         */
        public Builder build() {
            return parent;
        }
    }

    /**
     * DeviceInfo 嵌套 Builder
     * 用于设置 deviceInfo 对象中的字段
     */
    public static class DeviceInfoBuilder {
        private final ClientInfoBuilder parent;
        private final Map<String, Object> deviceInfoMap;
        private final Map<String, Object> rootArguments;
        
        DeviceInfoBuilder(ClientInfoBuilder parent, Map<String, Object> clientInfoMap) {
            this.parent = parent;
            this.deviceInfoMap = new HashMap<>();
            this.rootArguments = parent.parent.options.arguments;
            clientInfoMap.put("deviceInfo", deviceInfoMap);
        }

        public DeviceInfoBuilder setBoard(String board) {
            deviceInfoMap.put("board", board);
            return this;
        }

        public DeviceInfoBuilder setBoxflag(String boxflag) {
            deviceInfoMap.put("boxflag", boxflag);
            return this;
        }

        public DeviceInfoBuilder setBrand(String brand) {
            deviceInfoMap.put("brand", brand);
            return this;
        }

        public DeviceInfoBuilder setBrhShtName(String brhShtName) {
            deviceInfoMap.put("brhShtName", brhShtName);
            return this;
        }

        public DeviceInfoBuilder setDeviceInst(String deviceInst) {
            deviceInfoMap.put("deviceInst", deviceInst);
            return this;
        }

        public DeviceInfoBuilder setDeviceNo(String deviceNo) {
            deviceInfoMap.put("deviceNo", deviceNo);
            // 同时设置顶层的 deviceId
            rootArguments.put("deviceId", deviceNo);
            return this;
        }

        public DeviceInfoBuilder setDisplay(String display) {
            deviceInfoMap.put("display", display);
            return this;
        }

        public DeviceInfoBuilder setGps(String gps) {
            deviceInfoMap.put("gps", gps);
            return this;
        }

        public DeviceInfoBuilder setImei(String imei) {
            deviceInfoMap.put("imei", imei);
            return this;
        }

        public DeviceInfoBuilder setModel(String model) {
            deviceInfoMap.put("model", model);
            return this;
        }

        public DeviceInfoBuilder setOsVersion(String osVersion) {
            deviceInfoMap.put("osVersion", osVersion);
            return this;
        }

        public DeviceInfoBuilder setSdk(String sdk) {
            deviceInfoMap.put("sdk", sdk);
            return this;
        }

        public DeviceInfoBuilder setUpdeviceInst(String updeviceInst) {
            deviceInfoMap.put("updeviceInst", updeviceInst);
            return this;
        }

        /**
         * 返回父 ClientInfoBuilder
         */
        public ClientInfoBuilder build() {
            return parent;
        }
    }

    public String getRoute() {
        return route;
    }

    public Map<String, Object> getArguments() {
        return arguments;
    }

    @Override
    public String toString() {
        return "ConferenceOptions{" +
                "route='" + route + '\'' +
                ", arguments=" + arguments +
                '}';
    }
}
````

## File: rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/FlutterDemoActivity.java
````java
package com.yc.rtc.rsc_sdk;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import org.json.JSONObject;

import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;

/**
 * Flutter 承载 Activity (SDK 内部实现)
 */
public class FlutterDemoActivity extends FlutterFragmentActivity {
    private static final String TAG = "FlutterDemoActivity";
    private static final String FLUTTER_ENGINE_ID = "xchatkit_engine";

    private PipMethodChannelHandler pipHandler;

    @Override
    public String getCachedEngineId() {
        return FLUTTER_ENGINE_ID;
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // [Perf] 执行 Dart 入口点（从 InitXChatKit 延迟到这里）
        SDLActivityAdapter.ExecuteDartEntrypoint();
        
        SDLActivityAdapter.EnsureMethodChannelReady();
        if (pipHandler == null) {
            pipHandler = new PipMethodChannelHandler(this);
            pipHandler.register(flutterEngine);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {

        // 1. 确保引擎已初始化
        SDLActivityAdapter.InitXChatKit(this, false);

        super.onCreate(savedInstanceState);

        // 2. 解析 Intent 参数
        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
    }

    @SuppressWarnings("unchecked")
    private void handleIntent(Intent intent) {
        if (intent == null) return;

        String route = intent.getStringExtra("route");
        if (route == null) route = "/room"; // 默认路由

        Map<String, Object> arguments = null;
        if (intent.hasExtra("arguments_bundle")) {
            Bundle bundle = intent.getBundleExtra("arguments_bundle");
            if (bundle != null) {
                Serializable serializable = bundle.getSerializable("arguments");
                if (serializable instanceof Map) {
                    arguments = (Map<String, Object>) serializable;
                }
            }
        }

        Log.i(TAG, "handleIntent arguments: " + arguments);

        // 3. 处理 userData：优先使用 ConferenceOptions 传递的参数
        //    ConferenceOptions 的字段（fromuser, clientInfo 等）在 arguments 顶层
        //    需要合并到 userData 对象中
        if (arguments != null && !arguments.isEmpty()) {
            try {
                JSONObject userDataJson = new JSONObject();
                
                // 检查是否存在 ConferenceOptions 的字段
                boolean hasConferenceOptionsFields = false;
                
                // 顶层字段映射
                String[] userDataFields = {"fromuser", "brhName", "unionId", "deviceId", "language", "languageName", "browser", "busitype1", "visitorSendInst", "r_flag", "appid", "dept", "channelName", "init", "noAgentLogin", "p2p", "queueHintCount", "queueHintInterval"};
                for (String field : userDataFields) {
                    if (arguments.containsKey(field)) {
                        userDataJson.put(field, arguments.get(field));
                        hasConferenceOptionsFields = true;
                    }
                }
                
                Log.i(TAG, "handleIntent userDataJson: " + userDataJson.toString());
                
                // 检查 clientInfo 嵌套对象
                if (arguments.containsKey("clientInfo")) {
                    Object clientInfoObj = arguments.get("clientInfo");
                    if (clientInfoObj instanceof Map) {
                        userDataJson.put("clientInfo", new JSONObject((Map) clientInfoObj));
                        hasConferenceOptionsFields = true;
                    }
                }
                
                // 如果有 ConferenceOptions 字段，缓存到 Adapter
                if (hasConferenceOptionsFields) {
                    Log.i(TAG, "Using ConferenceOptions fields: " + userDataJson.toString());
                    SDLActivityAdapter.CacheUserData(userDataJson.toString());
                }
            } catch (Exception e) {
                Log.e(TAG, "Failed to process ConferenceOptions fields", e);
            }
        }

        // 4. 执行数据初始化 (合并 assets 配置)
        initXchatData();

        // 5. 执行跳转 (通知 Flutter)
        Log.i(TAG, "Navigating to: " + route);
        Log.i(TAG, "Navigating data: " + SDLActivityAdapter.getCachedXChatData());
        SDLActivityAdapter.PerformNavigation(route, SDLActivityAdapter.getCachedXChatData());
    }

    private void initXchatData() {
        try {
            // 获取外部设置的数据 (可能来自 setStaticUserData，也可能来自 handleIntent 解析)
            String externalUserDataStr = SDLActivityAdapter.getCachedUserData();

            // 动态加载当前环境的配置文件
            XChatKitConfig config = XChatKitConfig.fromAssetsConfig(this, XChatKit.getConfigFileName());
            XChatKitConfig.MediaInfo mediaInfo = config.getMediaInfo();
            
            // 1. 构建 mediaInfo 对象
            JSONObject mediaInfoJson = new JSONObject();
            mediaInfoJson.put("mediaEntranceUrl", mediaInfo.getMediaEntranceUrl());
            mediaInfoJson.put("mgwUrl", mediaInfo.getMgwUrl());
            mediaInfoJson.put("roomMode", mediaInfo.getRoomMode());
            mediaInfoJson.put("roomId", mediaInfo.getRoomId());
            mediaInfoJson.put("peerType", mediaInfo.getPeerType());
            mediaInfoJson.put("aCenter", mediaInfo.getACenter());
            mediaInfoJson.put("bCenter", mediaInfo.getBCenter());
            mediaInfoJson.put("probe", mediaInfo.getProbe());
            
            if (!mediaInfo.getIceServers().isEmpty()) {
                JSONObject iceServersWrapper = new JSONObject(mediaInfo.getIceServers());
                mediaInfoJson.put("iceServers", iceServersWrapper.get("iceServers"));
            }
            // proxy 信息保留在mediaInfo层级
            if (System.getProperty("http.proxyHost") != null) {
                mediaInfoJson.put("proxyIp", System.getProperty("http.proxyHost"));
            }
            Log.i(TAG, "initXchatData getProxyIp：" + System.getProperty("http.proxyHost"));
            if (System.getProperty("http.proxyPort") != null) {
                mediaInfoJson.put("proxyPort", System.getProperty("http.proxyPort"));
            }
            Log.i(TAG, "initXchatData getProxyPort：" + System.getProperty("http.proxyPort"));

            // 2. 构建 user_data 对象
            JSONObject userDataJson;
            if (externalUserDataStr != null && !externalUserDataStr.isEmpty()) {
                userDataJson = new JSONObject(externalUserDataStr);
            } else {
                userDataJson = config.getUserData().toJSONObject();
            }
            
            // 3. mediaInfo.peerId 从 user_data.fromuser 获取
            if (userDataJson.has("fromuser")) {
                mediaInfoJson.put("peerId", userDataJson.getString("fromuser"));
            } else {
                mediaInfoJson.put("peerId", mediaInfo.getPeerId());
            }
            
            // 4. 构建最终嵌套JSON
            final JSONObject finalJson = new JSONObject();
            finalJson.put("mediaInfo", mediaInfoJson);
            finalJson.put("userData", userDataJson);

            Log.i(TAG, "initXchatData：" + finalJson);
            SDLActivityAdapter.CacheXChatData(finalJson.toString());
        } catch (Exception e) {
            Log.e(TAG, "initUserDataLogic failed", e);
        }
    }

    @Override
    public void onPictureInPictureModeChanged(boolean isInPictureInPictureMode, android.content.res.Configuration newConfig) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig);
        if (pipHandler != null) pipHandler.onPipModeChanged(isInPictureInPictureMode);
    }

    @Override
    protected void onDestroy() {
        if (pipHandler != null) pipHandler.unregister();
        super.onDestroy();
//        SDLActivityAdapter.DestroyXChatKit();
    }
}
````

## File: rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/PipMethodChannelHandler.java
````java
package com.yc.rtc.rsc_sdk;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.ActivityManager;
import android.app.PictureInPictureParams;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * PiP（画中画）功能的 MethodChannel 处理器
 *
 * 功能说明：
 * 1. 检查设备是否支持PiP模式
 * 2. 进入/退出PiP模式
 * 3. 监听PiP状态变化并通知Flutter端
 *
 * 使用方法：
 * 在 Activity 的 configureFlutterEngine 中注册：
 * <pre>
 *   PipMethodChannelHandler pipHandler = new PipMethodChannelHandler(this);
 *   pipHandler.register(flutterEngine);
 * </pre>
 *
 * 在 Activity 的 onPictureInPictureModeChanged 中通知状态变化：
 * <pre>
 *   @Override
 *   public void onPictureInPictureModeChanged(boolean isInPictureInPictureMode, Configuration newConfig) {
 *       super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig);
 *       pipHandler.onPipModeChanged(isInPictureInPictureMode);
 *   }
 * </pre>
 */
public class PipMethodChannelHandler implements MethodChannel.MethodCallHandler {

    private static final String TAG = "PipMethodChannel";
    private static final String CHANNEL = "com.yc.rtc/pip";
    private static final String EVENT_CHANNEL = "com.yc.rtc/pip_events";

    private final Activity activity;
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;

    public PipMethodChannelHandler(FlutterDemoActivity activity) {
        this.activity = activity;
    }

    /**
     * 注册 MethodChannel 和 EventChannel
     *
     * @param flutterEngine Flutter引擎实例
     */
    public void register(io.flutter.embedding.engine.FlutterEngine flutterEngine) {
        // 注册方法通道
        methodChannel = new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            CHANNEL
        );
        methodChannel.setMethodCallHandler(this);

        // 注册事件通道
        eventChannel = new EventChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            EVENT_CHANNEL
        );
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
                // 立即发送当前PiP状态
                sendPipModeChanged(isInPipMode());
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });

        Log.d(TAG, "PipMethodChannelHandler registered");
    }

    /**
     * 注销通道
     */
    public void unregister() {
        if (methodChannel != null) {
            methodChannel.setMethodCallHandler(null);
            methodChannel = null;
        }
        if (eventChannel != null) {
            eventChannel.setStreamHandler(null);
            eventChannel = null;
        }
        eventSink = null;
        Log.d(TAG, "PipMethodChannelHandler unregistered");
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "isPipSupported":
                result.success(isPipSupported());
                break;

            case "enterPipMode":
                boolean entered = enterPipMode(call);
                result.success(entered);
                break;

            case "exitPipMode":
                boolean exited = exitPipMode();
                result.success(exited);
                break;

            default:
                result.notImplemented();
                break;
        }
    }

    /**
     * 检查设备是否支持PiP模式
     *
     * @return true表示支持，false表示不支持
     */
    private boolean isPipSupported() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.d(TAG, "PiP not supported: Android version < 8.0");
            return false;
        }

        PackageManager pm = activity.getPackageManager();
        boolean hasFeature = pm.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE);
        Log.d(TAG, "PiP support check: " + hasFeature);
        return hasFeature;
    }

    /**
     * 进入PiP模式
     *
     * @param call 方法调用，可能包含宽高比参数
     * @return true表示成功进入，false表示失败
     */
    private boolean enterPipMode(MethodCall call) {
        if (!isPipSupported()) return false;

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // 1. 不解锁方向 (保持横屏进入)
                // activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);

                // 2. 【核心】创建一个空的 Params
                // 不设置 setAspectRatio (让系统自己决定比例，避开导航栏计算冲突)
                // 不设置 setSourceRectHint (防止动画导致的 Surface 销毁)
                // 不设置 setAutoEnterEnabled
                PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder();

                // 仅仅 build，没有任何参数
                return activity.enterPictureInPictureMode(builder.build());
            }
        } catch (Exception e) {
            Log.e(TAG, "Error entering PiP", e);
        }
        return false;
    }

    /**
     * 退出PiP模式（恢复正常窗口）
     *
     * @return true表示成功退出，false表示失败
     */
    @SuppressLint("MissingPermission")
    private boolean exitPipMode() {
        if (!isInPipMode()) {
            Log.d(TAG, "Not in PiP mode, no need to exit");
            return true;
        }

        try {
            // 方法1：通过ActivityManager将任务移到前台（推荐）
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ActivityManager activityManager = (ActivityManager) activity.getSystemService(Context.ACTIVITY_SERVICE);
                if (activityManager != null) {
                    activityManager.moveTaskToFront(activity.getTaskId(), 0);
                    Log.d(TAG, "Exit PiP mode: moved task to front");
                    return true;
                }
            }

            // 方法2（备用）：重新启动Activity会自动退出PiP
            Intent intent = new Intent(activity, activity.getClass());
            intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
            activity.startActivity(intent);
            Log.d(TAG, "Exit PiP mode: restarted activity");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error exiting PiP mode", e);
            return false;
        }
    }

    /**
     * 检查当前是否处于PiP模式
     *
     * @return true表示在PiP模式，false表示不在
     */
    private boolean isInPipMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return activity.isInPictureInPictureMode();
        }
        return false;
    }

    /**
     * 当PiP模式改变时调用此方法
     * 应该在 Activity 的 onPictureInPictureModeChanged 中调用
     *
     * @param isInPipMode 是否处于PiP模式
     */
    public void onPipModeChanged(boolean isInPipMode) {
        Log.d(TAG, "PiP mode changed: " + isInPipMode);
        sendPipModeChanged(isInPipMode);
    }

    /**
     * 通过EventChannel发送PiP状态变化事件
     *
     * @param isInPipMode 是否处于PiP模式
     */
    private void sendPipModeChanged(boolean isInPipMode) {
        if (eventSink != null) {
            Map<String, Object> event = new HashMap<>();
            event.put("isInPipMode", isInPipMode);
            activity.runOnUiThread(() -> eventSink.success(event));
        }
    }
}
````

## File: rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/SDLActivityAdapter.java
````java
package com.yc.rtc.rsc_sdk;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

//import com.gsc.provider.sdk.ProviderManager;

import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * SDLActivity适配层 (SDK 内部实现)
 */
class SDLActivityAdapter {
    private static final String TAG = "SDLActivityAdapter";
    // 控制详细日志输出，生产环境建议设为 false
    private static final boolean DEBUG = true;

    // 通道名称定义（需与 Flutter 端保持一致）
    private static final String METHOD_CHANNEL_NAME = "xchatkit";
    private static final String EVENT_CHANNEL_NAME = "xchatkit";
    private static final String FLUTTER_ENGINE_ID = "xchatkit_engine";

    // Flutter 引擎与通道
    private static FlutterEngine flutterEngine;
    private static Context applicationContext;
    
    // 使用弱引用防止 Activity 泄漏
    private static WeakReference<Activity> currentActivityRef;
    
    private static MethodChannel methodChannel;
    private static EventChannel eventChannel;
    private static EventSink eventSink;

    // 引擎就绪状态管理
    private static boolean isEngineReady = false;
    private static Map<String, Object> pendingNavigation = null;

    // 监听器
    private static CallEventListener callEventListener;
    private static XChatKit.OnBusinessPhotoTakeListener pendingBusinessPhotoListener;

    // 线程控制
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    // 缓存数据
    private static String cachedUserData = null;   // 宿主传入的用户片段
    private static String cachedXChatData = null;  // 合并后的完整数据

    // 性能埋点
    private static long sStartTime = 0;
    private static final FlutterUiDisplayListener uiListener = new FlutterUiDisplayListener() {
        @Override
        public void onFlutterUiDisplayed() {
            long endTime = System.currentTimeMillis();
            Log.i(TAG, "[Perf] onFlutterUiDisplayed callback triggered!");
            if (sStartTime > 0) {
                Log.i(TAG, "[Perf] First Frame Rendered at: " + endTime);
                Log.i(TAG, "[Perf] Total Launch Time: " + (endTime - sStartTime) + " ms");
            }
        }

        @Override
        public void onFlutterUiNoLongerDisplayed() {
            Log.i(TAG, "[Perf] onFlutterUiNoLongerDisplayed");
        }
    };

    /**
     * 获取当前的 FlutterEngine 实例
     */
    public static FlutterEngine GetFlutterEngine() {
        return flutterEngine;
    }

    /**
     * 初始化 XChatKit (Context 版本，用于 Application 预热)
     * 优化：只创建 FlutterEngine 缓存，不执行 Dart entrypoint（延迟到 FlutterDemoActivity）
     */
    public static void InitXChatKit(Context context) {
        if (context == null) {
            throw new IllegalArgumentException("Context cannot be null");
        }
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(() -> InitXChatKit(context));
            return;
        }

        try {
            if (flutterEngine == null) {
                applicationContext = context.getApplicationContext();
                flutterEngine = new FlutterEngine(applicationContext);
                
                // [Perf] 创建时即添加监听
                flutterEngine.getRenderer().addIsDisplayingFlutterUiListener(uiListener);
                
                FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine);
                isEngineReady = false; // 重置状态
                Log.i(TAG, "InitXChatKit: FlutterEngine created and cached (Pre-warm, no Dart execution yet).");
            }
            setupMethodChannel();
            setupEventChannel();
            // [Perf] 不再在此处执行 Dart entrypoint，延迟到 FlutterDemoActivity
            // 这样可以避免在 init() 时加载 Dart 代码，减少首次启动时间
            SDLActivityAdapter.EnsureMethodChannelReady();
            Log.i(TAG, "InitXChatKit End (engine pre-warmed, Dart deferred)");
        } catch (Exception e) {
            Log.e(TAG, "InitXChatKit(Context) failed", e);
        }
    }

    public static void InitXChatKit(Activity activity, boolean autoStart) {
        if (activity == null) throw new IllegalArgumentException("Activity cannot be null");
        
        currentActivityRef = new WeakReference<>(activity);
        
        InitXChatKit(activity.getApplicationContext());
        if (autoStart) StartFlutterActivity(activity, "/");
    }

    public static void InitXChatKit(Activity activity) {
        InitXChatKit(activity, false);
    }

    /**
     * 预热 Flutter 引擎接口
     */
    public interface OnPrewarmListener {
        void onPrewarmSuccess();
        void onPrewarmFailed(String error);
    }

    /**
     * 异步预热 Flutter 引擎
     * @param context 应用上下文
     * @param engineId 引擎缓存 ID
     * @param listener 预热完成回调
     */
    public static void PrewarmFlutterEngine(Context context, String engineId, OnPrewarmListener listener) {
        if (context == null) {
            if (listener != null) {
                listener.onPrewarmFailed("Context cannot be null");
            }
            return;
        }

        // 检查引擎是否已缓存
        FlutterEngine cachedEngine = FlutterEngineCache.getInstance().get(engineId);
        if (cachedEngine != null) {
            // 检查 Dart 是否已执行
            if (!cachedEngine.getDartExecutor().isExecutingDart()) {
                Log.i(TAG, "PrewarmFlutterEngine: Engine cached but Dart not executed, executing now...");
                cachedEngine.getDartExecutor().executeDartEntrypoint(
                        DartExecutor.DartEntrypoint.createDefault()
                );
            }
            Log.i(TAG, "PrewarmFlutterEngine: Using cached engine");
            if (listener != null) {
                listener.onPrewarmSuccess();
            }
            return;
        }

        try {
            applicationContext = context.getApplicationContext();
            FlutterEngine engine = new FlutterEngine(applicationContext);
            
            // 添加 UI 监听器
            engine.getRenderer().addIsDisplayingFlutterUiListener(uiListener);
            
            // 执行 Dart entrypoint 以完整预热引擎
            engine.getDartExecutor().executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
            );
            
            FlutterEngineCache.getInstance().put(engineId, engine);
            Log.i(TAG, "PrewarmFlutterEngine: Engine created, Dart executed, and cached successfully");
            if (listener != null) {
                listener.onPrewarmSuccess();
            }
        } catch (Exception e) {
            Log.e(TAG, "PrewarmFlutterEngine failed", e);
            if (listener != null) {
                listener.onPrewarmFailed(e.getMessage());
            }
        }
    }

    /**
     * 获取缓存的 Flutter 引擎
     * @param engineId 引擎缓存 ID
     * @return 缓存的引擎，如果不存在则返回 null
     */
    public static FlutterEngine getCachedEngine(String engineId) {
        return FlutterEngineCache.getInstance().get(engineId);
    }

    /**
     * 清理缓存的 Flutter 引擎
     * @param engineId 引擎缓存 ID
     */
    public static void clearCachedEngine(String engineId) {
        FlutterEngine engine = FlutterEngineCache.getInstance().get(engineId);
        if (engine != null) {
            FlutterEngineCache.getInstance().remove(engineId);
            Log.i(TAG, "Cached engine removed: " + engineId);
        }
    }

    public static void EnsureMethodChannelReady() {
        if (flutterEngine == null) return;
        if (methodChannel == null) {
            setupMethodChannel();
        } else {
            methodChannel.setMethodCallHandler((call, result) -> handleMethodCall(call, result));
        }
    }

    /**
     * 执行 Dart 入口点（在 FlutterDemoActivity 中调用）
     * [Perf] 延迟执行 Dart 代码，减少 init() 时的预热时间
     */
    public static void ExecuteDartEntrypoint() {
        if (flutterEngine == null) {
            Log.w(TAG, "ExecuteDartEntrypoint: flutterEngine is null");
            return;
        }
        if (!flutterEngine.getDartExecutor().isExecutingDart()) {
            flutterEngine.getDartExecutor().executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
            );
            Log.i(TAG, "ExecuteDartEntrypoint: Dart entrypoint executed.");
        } else {
            Log.i(TAG, "ExecuteDartEntrypoint: Dart already executing.");
        }
    }

    private static void setupMethodChannel() {
        methodChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                METHOD_CHANNEL_NAME
        );
        methodChannel.setMethodCallHandler((call, result) -> handleMethodCall(call, result));
    }

    private static void setupEventChannel() {
        eventChannel = new EventChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                EVENT_CHANNEL_NAME
        );
        eventChannel.setStreamHandler(new StreamHandler() {
            @Override
            public void onListen(Object arguments, EventSink events) {
                if (Looper.myLooper() == Looper.getMainLooper()) eventSink = events;
                else mainHandler.post(() -> eventSink = events);
            }
            @Override
            public void onCancel(Object arguments) {
                if (Looper.myLooper() == Looper.getMainLooper()) eventSink = null;
                else mainHandler.post(() -> eventSink = null);
            }
        });
    }

    private static void handleMethodCall(MethodCall call, Result result) {
        if (DEBUG) Log.d(TAG, "handleMethodCall: " + call.method);
        try {
            switch (call.method) {
                case "engineReady":
                    // Flutter 端通知：引擎已就绪
                    isEngineReady = true;
                    Log.i(TAG, "Flutter Engine is READY.");
                    // 如果有挂起的导航请求，立即执行
                    if (pendingNavigation != null) {
                        Log.i(TAG, "Executing pending navigation...");
                        String route = (String) pendingNavigation.get("route");
                        String args = (String)pendingNavigation.get("arguments");
                        performFlutterNavigation(route, args);
                        pendingNavigation = null;
                    }
                    result.success(null);
                    break;

                case "getUserData":
                    // 返回合并后的完整数据
                    if (cachedXChatData != null) {
                        result.success(cachedXChatData);
                    } else {
                        result.error("NO_DATA", "No integrated data cached", null);
                    }
                    break;
                case "onPhotoCaptured":
                    if (call.arguments instanceof byte[]) {
                        byte[] photoData = (byte[]) call.arguments;
                        onPhotoEvent(photoData);
                    }
                    result.success(null);
                    break;
                case "onBusinessPhotoTakeSuccess":
                    String filePath = (String) call.arguments;
                    Log.i(TAG, "onBusinessPhotoTakeSuccess: " + filePath);
                    if (pendingBusinessPhotoListener != null) {
                        pendingBusinessPhotoListener.onPhotoTakeSuccess(filePath);
                        pendingBusinessPhotoListener = null;
                    }
                    result.success(null);
                    break;
                case "onBusinessPhotoTakeFail":
                    Log.i(TAG, "onBusinessPhotoTakeFail");
                    if (pendingBusinessPhotoListener != null) {
                        pendingBusinessPhotoListener.onPhotoTakeFail();
                        pendingBusinessPhotoListener = null;
                    }
                    result.success(null);
                    break;
                case "onBusinessPhotoResult":
                    Log.i(TAG, "onBusinessPhotoResult received");
                    ArrayList<String> filePaths = (ArrayList<String>) call.arguments;
                    Log.i(TAG, "onBusinessPhotoResult: " + filePaths);
                    if (pendingBusinessPhotoListener != null) {
                        pendingBusinessPhotoListener.onPhotoApiSuccess(filePaths);
                        pendingBusinessPhotoListener = null;
                    }
                    result.success(null);
                    break;
                case "onBusinessPhotoApiFail":
                    String errorMessage = (String) call.arguments;
                    Log.i(TAG, "onBusinessPhotoApiFail: " + errorMessage);
                    if (pendingBusinessPhotoListener != null) {
                        pendingBusinessPhotoListener.onPhotoApiFail(errorMessage);
                        pendingBusinessPhotoListener = null;
                    }
                    result.success(null);
                    break;
                case "onEvent":
                    Map<String, Object> args = (Map<String, Object>) call.arguments;
                    Log.d(TAG, "handleMethodCall onEvent:" +  args.toString());
                    onEvent((String) args.get("event"), (String) args.get("message"), String.valueOf(args.getOrDefault("timestamp", 0L)));
                    result.success(null);
                    break;
                case "onReceiveMessage":
                    String message = (String) call.arguments;
                    Log.d(TAG, "handleMethodCall onReceiveMessage: " + message);
                    onReceiveMessageEvent(message);
                    result.success(null);
                    break;
//                case "getSdpProxyInfo":
//                    handleGetSdpProxyInfo(result);
//                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            Log.e(TAG, "handleMethodCall exception", e);
            result.error("ERROR", e.getMessage(), null);
        }
    }

    /**
     * 执行 Flutter 页面跳转
     *
     */
    public static void PerformNavigation(String route, String arguments) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(() -> PerformNavigation(route, arguments));
            return;
        }

        // 方案：检查 Dart 是否正在执行，而不依赖 Flutter UI 渲染完成的通知
        // 这样预热后的 Dart 代码执行完成就能直接跳转，不需要等 UI 渲染
        boolean dartIsExecuting = flutterEngine != null && 
                                   flutterEngine.getDartExecutor().isExecutingDart();
        
        if (dartIsExecuting) {
            // Dart 已经在执行，可以直接跳转
            Log.i(TAG, "Dart is executing, performing navigation directly");
            performFlutterNavigation(route, arguments);
        } else if (isEngineReady) {
            // 兼容：Flutter 通知的 engineReady（UI 渲染完成后）
            Log.i(TAG, "Engine ready (UI rendered), performing navigation");
            performFlutterNavigation(route, arguments);
        } else {
            // 引擎未就绪，缓存请求
            Log.i(TAG, "Engine not ready, caching navigation request for: " + route);
            pendingNavigation = new HashMap<>();
            pendingNavigation.put("route", route);
            pendingNavigation.put("arguments", arguments);
        }
    }

    private static void performFlutterNavigation(String route, String arguments) {
        if (methodChannel == null) return;
        Map<String, Object> params = new HashMap<>();
        params.put("route", route);
        params.put("arguments", arguments);
        Log.i(TAG, "performFlutterNavigation data: " + params);
        methodChannel.invokeMethod("navigatorPush", params);
    }

//    private static void handleGetSdpProxyInfo(Result result) {
//        Activity activity = (currentActivityRef != null) ? currentActivityRef.get() : null;
//        if (activity == null) {
//            result.error("ERROR", "Activity is null or destroyed", null);
//            return;
//        }
//        GetSdpProxyInfo(activity, proxyInfo -> {
//            if (proxyInfo != null) {
//                Map<String, Object> map = new HashMap<>();
//                map.put("proxyIp", proxyInfo.optString("proxyIp"));
//                map.put("proxyPort", proxyInfo.optInt("proxyPort"));
//                result.success(map);
//            } else {
//                result.success(null);
//            }
//        });
//    }

    /**
     * 供宿主 App 设置用户信息片段
     */
    public static void CacheUserData(String userData) {
        cachedUserData = userData;
        if (DEBUG) Log.d(TAG, "User Identity cached.");
    }

    static String getCachedUserData() {
        return cachedUserData;
    }

    /**
     * 供 SDK 内部设置合并后的完整数据
     */
    public static void CacheXChatData(String data) {
        cachedXChatData = data;
        if (DEBUG) Log.d(TAG, "Integrated XChatData cached.");
    }

    static String getCachedXChatData() {
        return cachedXChatData;
    }

//    public static void GetSdpProxyInfo(Activity activity, GetSdpProxyInfoCallback callback) {
//        if (activity == null) { if (callback != null) callback.onResult(null); return; }
//        if (Looper.myLooper() != Looper.getMainLooper()) {
//            mainHandler.post(() -> GetSdpProxyInfo(activity, callback));
//            return;
//        }
//        try {
//            ProviderManager.getInstance().bindService(activity.getApplicationContext(), new ProviderManager.ConnectResultListener() {
//                @Override
//                public void success() {
//                    try {
//                        String netData = ProviderManager.getInstance().getData(64);
//                        if (netData != null && new JSONObject(netData).optInt("code") == 0) {
//                            if ("SDP".equals(new JSONObject(netData).optJSONObject("data").optString("netType"))) {
//                                String proxy = ProviderManager.getInstance().getData(128);
//                                if (proxy != null && !"type_error".equals(proxy)) {
//                                    JSONObject pJson = new JSONObject(proxy).optJSONObject("data");
//                                    if (pJson != null) {
//                                        JSONObject res = new JSONObject();
//                                        res.put("proxyIp", pJson.optString("ip"));
//                                        res.put("proxyPort", pJson.optInt("port"));
//                                        if (callback != null) callback.onResult(res);
//                                        return;
//                                    }
//                                }
//                            }
//                        }
//                        if (callback != null) callback.onResult(null);
//                    } catch (Exception e) { if (callback != null) callback.onResult(null); }
//                }
//                @Override public void fail() { if (callback != null) callback.onResult(null); }
//            });
//        } catch (Exception e) { if (callback != null) callback.onResult(null); }
//    }

    public static void onEvent(String event, String message, String time) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(() -> onEvent(event, message, time));
            return;
        }
        if (callEventListener != null) {
            try {
                callEventListener.onMessage(event, message, time);
            } catch (Exception e) { Log.e(TAG, "onEvent error", e); }
        }
    }

    public static void onReceiveMessageEvent(String message) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(() -> onReceiveMessageEvent(message));
            return;
        }
        if (callEventListener != null) {
            try {
                callEventListener.onReceiveMessage(message);
            } catch (Exception e) { Log.e(TAG, "onReceiveMessageEvent error", e); }
        }
    }

    public static void onPhotoEvent(byte[] data) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(() -> onPhotoEvent(data));
            return;
        }
        if (callEventListener != null) {
            try {
                callEventListener.onPhotoCaptured(data);
            } catch (Exception e) { Log.e(TAG, "onPhotoEvent error", e); }
        }
    }

    public static void StartFlutterActivity(Activity activity, String route) {
        if (activity == null) return;
        
        sStartTime = System.currentTimeMillis();
        Log.i(TAG, "[Perf] StartConference called at: " + sStartTime);
        
        if (flutterEngine == null) InitXChatKit(activity, false);
        
        if (flutterEngine != null) {
            flutterEngine.getRenderer().removeIsDisplayingFlutterUiListener(uiListener);
            flutterEngine.getRenderer().addIsDisplayingFlutterUiListener(uiListener);
            Log.i(TAG, "[Perf] Listener re-added to engine.");
        }
        
        currentActivityRef = new WeakReference<>(activity);
        
        if (!(activity instanceof FlutterActivity)) {
            Intent intent = FlutterActivity.withCachedEngine(FLUTTER_ENGINE_ID).build(activity);
            activity.startActivity(intent);
        }
    }

    public static void DestroyXChatKit() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(SDLActivityAdapter::DestroyXChatKit);
            return;
        }
        invokeMethod("destroyXChatKit", null);
        eventSink = null;
        if (eventChannel != null) { eventChannel.setStreamHandler(null); eventChannel = null; }
        if (methodChannel != null) { methodChannel.setMethodCallHandler(null); methodChannel = null; }
        if (flutterEngine != null) { FlutterEngineCache.getInstance().remove(FLUTTER_ENGINE_ID); flutterEngine.destroy(); flutterEngine = null; }
        
        if (currentActivityRef != null) {
            currentActivityRef.clear();
            currentActivityRef = null;
        }
        
        callEventListener = null;
        isEngineReady = false;
        pendingNavigation = null;
        Log.i(TAG, "DestroyXChatKit: Resources released.");
    }

    private static void invokeMethod(String method, Object args) {
        if (methodChannel == null) return;
        if (Looper.myLooper() != Looper.getMainLooper()) { mainHandler.post(() -> invokeMethod(method, args)); return; }
        methodChannel.invokeMethod(method, args);
    }

    public static void SetCallEventListener(CallEventListener listener) {
        callEventListener = listener;
        invokeMethod("setCallEventListener", listener != null);
    }

    public static void StartBusinessPhotoMode() { invokeMethod("startBusinessPhotoMode", null); }
    public static void StopBusinessPhotoMode() { invokeMethod("stopBusinessPhotoMode", null); }

    public static void SendMessage(String message) { invokeMethod("sendMessage", message); }

    public static void BusinessPhotoForGroup(String fileName, boolean isCustomerOnLeft, XChatKit.OnBusinessPhotoTakeListener listener) {
        pendingBusinessPhotoListener = listener;
        final Map<String, Object> params = new HashMap<>();
        params.put("fileName", fileName);
        if (!isCustomerOnLeft){
            isCustomerOnLeft = true;
        }
        params.put("isCustomerOnLeft", isCustomerOnLeft);
        invokeMethod("businessPhotoForGroup", params);
    }

    public static void BusinessPhotoForSingle(String fileName, boolean toggleCamera, String tipsContent, XChatKit.OnBusinessPhotoTakeListener listener) {
        pendingBusinessPhotoListener = listener;
        final Map<String, Object> params = new HashMap<>();
        params.put("fileName", fileName);
        params.put("toggleCamera", toggleCamera);
        params.put("tipsContent", tipsContent);
        invokeMethod("businessPhotoForSingle", params);
    }

    public static void MuteMicphone(int mute) { invokeMethod("muteMicphone", mute); }
    public static void MuteCamera(int mute) { invokeMethod("muteCamera", mute); }
    public static void SwitchCamera() { invokeMethod("switchCamera", null); }
    public static void StartSharing() { invokeMethod("startSharing", null); }
    public static void StopSharing() { invokeMethod("stopSharing", null); }
    public static void SendMsg2Agent(String msg) { invokeMethod("sendMsg2Agent", msg); }
    public static void SendDTMF(String dtmf) { invokeMethod("sendDTMF", dtmf); }
    public static void JoinConference() { invokeMethod("joinConference", null); }
    public static void LeaveConference() { invokeMethod("leaveConference", null); }

    /**
     * 请求退出会议并关闭页面
     * 逻辑：Native -> Flutter (requestExit) -> Flutter 业务清理 -> SystemNavigator.pop() -> Activity Finish
     */
    public static void StopConference() {
        Log.i(TAG, "StopConference requested from Native.");
        // 清理缓存数据，防止环境切换后残留
        cachedUserData = null;
        cachedXChatData = null;
        invokeMethod("requestExit", null);
    }

    public static byte[] TakePhoto(String peerId) {
        // 主线程检测，防止 ANR
        if (Looper.myLooper() == Looper.getMainLooper()) {
            Log.e(TAG, "WARNING: Calling TakePhoto on MainThread! This may cause ANR (Application Not Responding). " +
                    "Please call this method from a background thread or use asynchronous API.");
        }

        if (methodChannel == null) return null;
        final byte[][] res = new byte[1][];
        final Object lock = new Object();
        mainHandler.post(() -> {
            try {
                methodChannel.invokeMethod("takePhoto", peerId, new Result() {
                    @Override public void success(Object result) { synchronized (lock) { if (result instanceof byte[]) res[0] = (byte[]) result; lock.notify(); } }
                    @Override public void error(String c, String m, Object d) { synchronized (lock) { lock.notify(); } }
                    @Override public void notImplemented() { synchronized (lock) { lock.notify(); } }
                });
            } catch (Exception e) { synchronized (lock) { lock.notify(); } }
        });
        synchronized (lock) { try { lock.wait(5000); } catch (InterruptedException e) {} }
        return res[0];
    }

    public interface GetSdpProxyInfoCallback { void onResult(JSONObject proxyInfo); }
    public interface CallEventListener { 
        void onMessage(String msgtype, String message, String time); 
        void onReceiveMessage(String message);
        default void onPhotoCaptured(byte[] data) {}
    }
}
````

## File: rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/UserData.java
````java
package com.yc.rtc.rsc_sdk;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

/**
 * 用户数据类
 */
public class UserData {
    private String appid;
    private String authority;
    private String botUUID;
    private String brand;
    private String brhName;
    private String browser;
    private String busitype1;
    private String busitype2;
    private String channelName;
    private String completereason;
    private String customerStatus;
    private String dept;
    private String deviceSysType;
    private String deviceWinNo;
    private boolean digital;
    private boolean enableRobot;
    private boolean everDigital;
    private String exSessionid;
    private String fromuser;
    private String host;
    private int init;
    private String ip;
    private boolean isDigital;
    private String o_biztypeid;
    private String openId;
    private String p2p;
    private String phone;
    private int r_flag;
    private String readid;
    private String releaseReason;
    private String rules4client;
    private String screenGrayscFlag;
    private String sex;
    private String sfu4agent;
    private String sfu4client;
    private String unionId;
    private String userId;
    private String userName;
    private String wechatavatar;

    public UserData() {
    }

    // Getter and Setter methods
    public String getAppid() {
        return appid;
    }

    public void setAppid(String appid) {
        this.appid = appid;
    }

    public String getAuthority() {
        return authority;
    }

    public void setAuthority(String authority) {
        this.authority = authority;
    }

    public String getBotUUID() {
        return botUUID;
    }

    public void setBotUUID(String botUUID) {
        this.botUUID = botUUID;
    }

    public String getBrand() {
        return brand;
    }

    public void setBrand(String brand) {
        this.brand = brand;
    }

    public String getBrhName() {
        return brhName;
    }

    public void setBrhName(String brhName) {
        this.brhName = brhName;
    }

    public String getBrowser() {
        return browser;
    }

    public void setBrowser(String browser) {
        this.browser = browser;
    }

    public String getBusitype1() {
        return busitype1;
    }

    public void setBusitype1(String busitype1) {
        this.busitype1 = busitype1;
    }

    public String getBusitype2() {
        return busitype2;
    }

    public void setBusitype2(String busitype2) {
        this.busitype2 = busitype2;
    }

    public String getChannelName() {
        return channelName;
    }

    public void setChannelName(String channelName) {
        this.channelName = channelName;
    }

    public String getCompletereason() {
        return completereason;
    }

    public void setCompletereason(String completereason) {
        this.completereason = completereason;
    }

    public String getCustomerStatus() {
        return customerStatus;
    }

    public void setCustomerStatus(String customerStatus) {
        this.customerStatus = customerStatus;
    }

    public String getDept() {
        return dept;
    }

    public void setDept(String dept) {
        this.dept = dept;
    }

    public String getDeviceSysType() {
        return deviceSysType;
    }

    public void setDeviceSysType(String deviceSysType) {
        this.deviceSysType = deviceSysType;
    }

    public String getDeviceWinNo() {
        return deviceWinNo;
    }

    public void setDeviceWinNo(String deviceWinNo) {
        this.deviceWinNo = deviceWinNo;
    }

    public boolean isDigital() {
        return digital;
    }

    public void setDigital(boolean digital) {
        this.digital = digital;
    }

    public boolean isEnableRobot() {
        return enableRobot;
    }

    public void setEnableRobot(boolean enableRobot) {
        this.enableRobot = enableRobot;
    }

    public boolean isEverDigital() {
        return everDigital;
    }

    public void setEverDigital(boolean everDigital) {
        this.everDigital = everDigital;
    }

    public String getExSessionid() {
        return exSessionid;
    }

    public void setExSessionid(String exSessionid) {
        this.exSessionid = exSessionid;
    }

    public String getFromuser() {
        return fromuser;
    }

    public void setFromuser(String fromuser) {
        this.fromuser = fromuser;
    }

    public String getHost() {
        return host;
    }

    public void setHost(String host) {
        this.host = host;
    }

    public int getInit() {
        return init;
    }

    public void setInit(int init) {
        this.init = init;
    }

    public String getIp() {
        return ip;
    }

    public void setIp(String ip) {
        this.ip = ip;
    }

    public boolean getIsDigital() {
        return isDigital;
    }

    public void setIsDigital(boolean isDigital) {
        this.isDigital = isDigital;
    }

    public String getO_biztypeid() {
        return o_biztypeid;
    }

    public void setO_biztypeid(String o_biztypeid) {
        this.o_biztypeid = o_biztypeid;
    }

    public String getOpenId() {
        return openId;
    }

    public void setOpenId(String openId) {
        this.openId = openId;
    }

    public String getP2p() {
        return p2p;
    }

    public void setP2p(String p2p) {
        this.p2p = p2p;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public int getR_flag() {
        return r_flag;
    }

    public void setR_flag(int r_flag) {
        this.r_flag = r_flag;
    }

    public String getReadid() {
        return readid;
    }

    public void setReadid(String readid) {
        this.readid = readid;
    }

    public String getReleaseReason() {
        return releaseReason;
    }

    public void setReleaseReason(String releaseReason) {
        this.releaseReason = releaseReason;
    }

    public String getRules4client() {
        return rules4client;
    }

    public void setRules4client(String rules4client) {
        this.rules4client = rules4client;
    }

    public String getScreenGrayscFlag() {
        return screenGrayscFlag;
    }

    public void setScreenGrayscFlag(String screenGrayscFlag) {
        this.screenGrayscFlag = screenGrayscFlag;
    }

    public String getSex() {
        return sex;
    }

    public void setSex(String sex) {
        this.sex = sex;
    }

    public String getSfu4agent() {
        return sfu4agent;
    }

    public void setSfu4agent(String sfu4agent) {
        this.sfu4agent = sfu4agent;
    }

    public String getSfu4client() {
        return sfu4client;
    }

    public void setSfu4client(String sfu4client) {
        this.sfu4client = sfu4client;
    }

    public String getUnionId() {
        return unionId;
    }

    public void setUnionId(String unionId) {
        this.unionId = unionId;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    public String getWechatavatar() {
        return wechatavatar;
    }

    public void setWechatavatar(String wechatavatar) {
        this.wechatavatar = wechatavatar;
    }

    /**
     * 将UserData对象转换为Map
     */
    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("appid", appid != null ? appid : "");
        map.put("authority", authority != null ? authority : "");
        map.put("botUUID", botUUID != null ? botUUID : "");
        map.put("brand", brand != null ? brand : "");
        map.put("brhName", brhName != null ? brhName : "");
        map.put("browser", browser != null ? browser : "");
        map.put("busitype1", busitype1 != null ? busitype1 : "");
        map.put("busitype2", busitype2 != null ? busitype2 : "");
        map.put("channelName", channelName != null ? channelName : "");
        map.put("completereason", completereason != null ? completereason : "");
        map.put("customerStatus", customerStatus != null ? customerStatus : "");
        map.put("dept", dept != null ? dept : "");
        map.put("deviceSysType", deviceSysType != null ? deviceSysType : "");
        map.put("deviceWinNo", deviceWinNo != null ? deviceWinNo : "");
        map.put("digital", digital);
        map.put("enableRobot", enableRobot);
        map.put("everDigital", everDigital);
        map.put("exSessionid", exSessionid != null ? exSessionid : "");
        map.put("fromuser", fromuser != null ? fromuser : "");
        map.put("host", host != null ? host : "");
        map.put("init", init);
        map.put("ip", ip != null ? ip : "");
        map.put("isDigital", isDigital);
        map.put("o_biztypeid", o_biztypeid != null ? o_biztypeid : "");
        map.put("openId", openId != null ? openId : "");
        map.put("p2p", p2p != null ? p2p : "");
        map.put("phone", phone != null ? phone : "");
        map.put("r_flag", r_flag);
        map.put("readid", readid != null ? readid : "");
        map.put("releaseReason", releaseReason != null ? releaseReason : "");
        map.put("rules4client", rules4client != null ? rules4client : "");
        map.put("screenGrayscFlag", screenGrayscFlag != null ? screenGrayscFlag : "");
        map.put("sex", sex != null ? sex : "");
        map.put("sfu4agent", sfu4agent != null ? sfu4agent : "");
        map.put("sfu4client", sfu4client != null ? sfu4client : "");
        map.put("unionId", unionId != null ? unionId : "");
        map.put("userId", userId != null ? userId : "");
        map.put("userName", userName != null ? userName : "");
        map.put("wechatavatar", wechatavatar != null ? wechatavatar : "");
        return map;
    }

    /**
     * 将UserData对象转换为JSONObject
     */
    public JSONObject toJSONObject() throws JSONException {
        JSONObject json = new JSONObject();
        json.put("appid", appid != null ? appid : "");
        json.put("authority", authority != null ? authority : "");
        json.put("botUUID", botUUID != null ? botUUID : "");
        json.put("brand", brand != null ? brand : "");
        json.put("brhName", brhName != null ? brhName : "");
        json.put("browser", browser != null ? browser : "");
        json.put("busitype1", busitype1 != null ? busitype1 : "");
        json.put("busitype2", busitype2 != null ? busitype2 : "");
        json.put("channelName", channelName != null ? channelName : "");
        json.put("completereason", completereason != null ? completereason : "");
        json.put("customerStatus", customerStatus != null ? customerStatus : "");
        json.put("dept", dept != null ? dept : "");
        json.put("deviceSysType", deviceSysType != null ? deviceSysType : "");
        json.put("deviceWinNo", deviceWinNo != null ? deviceWinNo : "");
        json.put("digital", digital);
        json.put("enableRobot", enableRobot);
        json.put("everDigital", everDigital);
        json.put("exSessionid", exSessionid != null ? exSessionid : "");
        json.put("fromuser", fromuser != null ? fromuser : "");
        json.put("host", host != null ? host : "");
        json.put("init", init);
        json.put("ip", ip != null ? ip : "");
        json.put("isDigital", isDigital);
        json.put("o_biztypeid", o_biztypeid != null ? o_biztypeid : "");
        json.put("openId", openId != null ? openId : "");
        json.put("p2p", p2p != null ? p2p : "");
        json.put("phone", phone != null ? phone : "");
        json.put("r_flag", r_flag);
        json.put("readid", readid != null ? readid : "");
        json.put("releaseReason", releaseReason != null ? releaseReason : "");
        json.put("rules4client", rules4client != null ? rules4client : "");
        json.put("screenGrayscFlag", screenGrayscFlag != null ? screenGrayscFlag : "");
        json.put("sex", sex != null ? sex : "");
        json.put("sfu4agent", sfu4agent != null ? sfu4agent : "");
        json.put("sfu4client", sfu4client != null ? sfu4client : "");
        json.put("unionId", unionId != null ? unionId : "");
        json.put("userId", userId != null ? userId : "");
        json.put("userName", userName != null ? userName : "");
        json.put("wechatavatar", wechatavatar != null ? wechatavatar : "");
        return json;
    }

    /**
     * 从Map创建UserData对象
     */
    public static UserData fromMap(Map<String, Object> map) {
        UserData userData = new UserData();
        if (map == null) {
            return userData;
        }

        userData.setAppid((String) map.get("appid"));
        userData.setAuthority((String) map.get("authority"));
        userData.setBotUUID((String) map.get("botUUID"));
        userData.setBrand((String) map.get("brand"));
        userData.setBrhName((String) map.get("brhName"));
        userData.setBrowser((String) map.get("browser"));
        userData.setBusitype1((String) map.get("busitype1"));
        userData.setBusitype2((String) map.get("busitype2"));
        userData.setChannelName((String) map.get("channelName"));
        userData.setCompletereason((String) map.get("completereason"));
        userData.setCustomerStatus((String) map.get("customerStatus"));
        userData.setDept((String) map.get("dept"));
        userData.setDeviceSysType((String) map.get("deviceSysType"));
        userData.setDeviceWinNo((String) map.get("deviceWinNo"));
        userData.setDigital(map.get("digital") != null ? (Boolean) map.get("digital") : false);
        userData.setEnableRobot(map.get("enableRobot") != null ? (Boolean) map.get("enableRobot") : false);
        userData.setEverDigital(map.get("everDigital") != null ? (Boolean) map.get("everDigital") : false);
        userData.setExSessionid((String) map.get("exSessionid"));
        userData.setFromuser((String) map.get("fromuser"));
        userData.setHost((String) map.get("host"));
        userData.setInit(map.get("init") != null ? (Integer) map.get("init") : 0);
        userData.setIp((String) map.get("ip"));
        userData.setIsDigital(map.get("isDigital") != null ? (Boolean) map.get("isDigital") : false);
        userData.setO_biztypeid((String) map.get("o_biztypeid"));
        userData.setOpenId((String) map.get("openId"));
        userData.setP2p((String) map.get("p2p"));
        userData.setPhone((String) map.get("phone"));
        userData.setR_flag(map.get("r_flag") != null ? (Integer) map.get("r_flag") : 0);
        userData.setReadid((String) map.get("readid"));
        userData.setReleaseReason((String) map.get("releaseReason"));
        userData.setRules4client((String) map.get("rules4client"));
        userData.setScreenGrayscFlag((String) map.get("screenGrayscFlag"));
        userData.setSex((String) map.get("sex"));
        userData.setSfu4agent((String) map.get("sfu4agent"));
        userData.setSfu4client((String) map.get("sfu4client"));
        userData.setUnionId((String) map.get("unionId"));
        userData.setUserId((String) map.get("userId"));
        userData.setUserName((String) map.get("userName"));
        userData.setWechatavatar((String) map.get("wechatavatar"));

        return userData;
    }

    /**
     * 从JSONObject创建UserData对象
     */
    public static UserData fromJSONObject(JSONObject json) {
        UserData userData = new UserData();
        if (json == null) {
            return userData;
        }

        userData.setAppid(json.optString("appid", ""));
        userData.setAuthority(json.optString("authority", ""));
        userData.setBotUUID(json.optString("botUUID", ""));
        userData.setBrand(json.optString("brand", ""));
        userData.setBrhName(json.optString("brhName", ""));
        userData.setBrowser(json.optString("browser", ""));
        userData.setBusitype1(json.optString("busitype1", ""));
        userData.setBusitype2(json.optString("busitype2", ""));
        userData.setChannelName(json.optString("channelName", ""));
        userData.setCompletereason(json.optString("completereason", ""));
        userData.setCustomerStatus(json.optString("customerStatus", ""));
        userData.setDept(json.optString("dept", ""));
        userData.setDeviceSysType(json.optString("deviceSysType", ""));
        userData.setDeviceWinNo(json.optString("deviceWinNo", ""));
        userData.setDigital(json.optBoolean("digital", false));
        userData.setEnableRobot(json.optBoolean("enableRobot", false));
        userData.setEverDigital(json.optBoolean("everDigital", false));
        userData.setExSessionid(json.optString("exSessionid", ""));
        userData.setFromuser(json.optString("fromuser", ""));
        userData.setHost(json.optString("host", ""));
        userData.setInit(json.optInt("init", 0));
        userData.setIp(json.optString("ip", ""));
        userData.setIsDigital(json.optBoolean("isDigital", false));
        userData.setO_biztypeid(json.optString("o_biztypeid", ""));
        userData.setOpenId(json.optString("openId", ""));
        userData.setP2p(json.optString("p2p", ""));
        userData.setPhone(json.optString("phone", ""));
        userData.setR_flag(json.optInt("r_flag", 0));
        userData.setReadid(json.optString("readid", ""));
        userData.setReleaseReason(json.optString("releaseReason", ""));
        userData.setRules4client(json.optString("rules4client", ""));
        userData.setScreenGrayscFlag(json.optString("screenGrayscFlag", ""));
        userData.setSex(json.optString("sex", ""));
        userData.setSfu4agent(json.optString("sfu4agent", ""));
        userData.setSfu4client(json.optString("sfu4client", ""));
        userData.setUnionId(json.optString("unionId", ""));
        userData.setUserId(json.optString("userId", ""));
        userData.setUserName(json.optString("userName", ""));
        userData.setWechatavatar(json.optString("wechatavatar", ""));

        return userData;
    }
}
````

## File: rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatKit.java
````java
package com.yc.rtc.rsc_sdk;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.Serializable;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * XChatKit SDK 统一入口
 */
public class XChatKit {
    private static final String TAG = "XChatKit";

    // --- 事件常量定义 (消除 Magic Strings) ---
    public static final String EVENT_WEBCAM_ENABLED = "EnableWebcamAndUploadDone";
    public static final String EVENT_WEBCAM_DISABLED = "DisableWebcamAndUploadDone";
    public static final String EVENT_CONFERENCE_STOPPED = "StopConnectionDone";
    public static final String EVENT_CONFERENCE_STARTED = "StartConnectionDone";
    public static final String EVENT_LEAVE_ROOM_DONE = "LeaveRoomDone";
    public static final String EVENT_MATCH_AGENT_DONE = "matchAgentSuccess";

    // 环境定义
    public static final int ENV_PROD = 0;   // 生产环境 (默认)
    public static final int ENV_DEBUG = 1;  // 测试环境

    private static int sCurrentEnv = ENV_DEBUG;
    
    // --- 多监听器支持 ---
    private static final CopyOnWriteArrayList<XChatEventListener> listeners = new CopyOnWriteArrayList<>();
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());
    private static boolean isAdapterListenerSet = false;
    private static boolean isInitialized = false;
    private static boolean isEnginePrewarmed = false;
    private static final String ENGINE_ID = "xchatkit_engine";
    private static OnEnginePrewarmListener prewarmListener;
    private static long prewarmStartTime = 0;

    /**
     * 获取当前环境
     */
    public static int getEnvironment() {
        return sCurrentEnv;
    }

    /**
     * 设置 SDK 运行环境
     * 注意：必须在 startConference 之前调用生效
     * @param env XChatKit.ENV_PROD 或 XChatKit.ENV_DEBUG
     */
    public static void setEnvironment(int env) {
        sCurrentEnv = env;
        Log.i(TAG, "Environment set to: " + (env == ENV_DEBUG ? "DEBUG" : "PROD"));
    }

    /**
     * 获取当前环境对应的配置文件名 (内部使用)
     */
    public static String getConfigFileName() {
        return (sCurrentEnv == ENV_DEBUG) ? "xchatkit_config_debug.json" : "xchatkit_config.json";
    }

    /**
     * SDK 事件监听接口
     */
    public interface XChatEventListener {
        void onMessage(String msgType, String message, String time);
        void onReceiveMessage(String message);
        default void onPhotoCaptured(byte[] data) {}
    }

    /**
     * 业务拍照回调接口
     */
    public interface OnBusinessPhotoTakeListener {
        void onPhotoTakeSuccess(String filePath);
        void onPhotoTakeFail();
        void onPhotoApiSuccess(java.util.List<String> filePaths);
        void onPhotoApiFail(String errorMessage);
    }

    /**
     * Flutter 引擎预热回调接口
     */
    public interface OnEnginePrewarmListener {
        void onEnginePrewarmComplete();
        void onEnginePrewarmFailed(String error);
    }

    /**
     * 初始化 SDK (建议在 Application.onCreate 中调用)
     * @param context 应用上下文
     * @param listener 引擎预热完成回调（可为空）
     */
    public static void init(@NonNull Context context, @Nullable OnEnginePrewarmListener listener) {
        if (isInitialized) {
            Log.i(TAG, "init() already initialized, engine prewarmed: " + isEnginePrewarmed);
            if (listener != null) {
                if (isEnginePrewarmed) {
                    listener.onEnginePrewarmComplete();
                } else {
                    prewarmListener = listener;
                }
            }
            return;
        }
        
        Log.i(TAG, "Initializing XChatKit...");
        
        // 使用 applicationContext 避免 Context 泄漏
        Context appContext = context.getApplicationContext();
        SDLActivityAdapter.InitXChatKit(appContext);
        
        // 设置预热回调
        prewarmListener = listener;
        
        // 异步预热 Flutter 引擎
        prewarmFlutterEngine(appContext);
        
        isInitialized = true;
    }

    /**
     * 初始化 SDK (兼容旧版接口，不带回调)
     * @param context 应用上下文
     */
    public static void init(@NonNull Context context) {
        init(context, null);
    }

    /**
     * 异步预热 Flutter 引擎
     */
    private static void prewarmFlutterEngine(Context context) {
        if (isEnginePrewarmed) {
            Log.i(TAG, "Engine already prewarmed, skipping");
            notifyPrewarmComplete();
            return;
        }

        prewarmStartTime = System.currentTimeMillis();
        Log.i(TAG, "Starting Flutter engine prewarm...");

        // 在主线程执行引擎预热
        mainHandler.post(() -> {
            try {
                SDLActivityAdapter.PrewarmFlutterEngine(context, ENGINE_ID, new SDLActivityAdapter.OnPrewarmListener() {
                    @Override
                    public void onPrewarmSuccess() {
                        isEnginePrewarmed = true;
                        long duration = System.currentTimeMillis() - prewarmStartTime;
                        Log.i(TAG, "Flutter engine prewarmed successfully, duration: " + duration + "ms");
                        notifyPrewarmComplete();
                    }

                    @Override
                    public void onPrewarmFailed(String error) {
                        Log.e(TAG, "Flutter engine prewarm failed: " + error);
                        notifyPrewarmFailed(error);
                    }
                });
            } catch (Exception e) {
                Log.e(TAG, "Engine prewarm exception: " + e.getMessage());
                notifyPrewarmFailed(e.getMessage());
            }
        });
    }

    /**
     * 通知预热完成
     */
    private static void notifyPrewarmComplete() {
        if (prewarmListener != null) {
            mainHandler.post(() -> prewarmListener.onEnginePrewarmComplete());
        }
    }

    /**
     * 通知预热失败
     */
    private static void notifyPrewarmFailed(String error) {
        if (prewarmListener != null) {
            mainHandler.post(() -> prewarmListener.onEnginePrewarmFailed(error));
        }
    }

    /**
     * 绑定宿主生命周期，当宿主 onDestroy 时自动销毁 SDK
     */
    public static void bindLifecycle(androidx.lifecycle.LifecycleOwner owner) {
        if (owner != null) {
            owner.getLifecycle().addObserver(new XChatLifecycleObserver());
        }
    }

    /**
     * 创建会议 Activity 的 Intent (用于自定义启动方式)
     */
    public static Intent createConferenceIntent(Context context, ConferenceOptions options) {
        if (context == null) throw new IllegalArgumentException("context cannot be null");
        if (options == null) options = new ConferenceOptions.Builder().build();

        Intent intent = new Intent(context, FlutterDemoActivity.class);
        intent.putExtra("route", options.getRoute());
        
        Map<String, Object> args = options.getArguments();
        if (args != null && !args.isEmpty()) {
            Bundle argsBundle = new Bundle();
            argsBundle.putSerializable("arguments", (Serializable) args);
            intent.putExtra("arguments_bundle", argsBundle);
        }
        return intent;
    }

    /**
     * 设置用户数据 (不再推荐使用，请通过 startConference 传参)
     */
    @Deprecated
    public static void setUserData(String userDataJSON) {
        SDLActivityAdapter.CacheUserData(userDataJSON);
    }

    /**
     * 启动会议 (简化版，跳转默认路由)
     */
    public static void startConference(@NonNull Activity activity) {
        startConference(activity, new ConferenceOptions.Builder().build());
    }

    /**
     * 启动会议 (使用 ConferenceOptions)
     */
    public static void startConference(@NonNull Activity activity, ConferenceOptions options) {
        if (!isInitialized) {
            throw new IllegalStateException("XChatKit.init() must be called before startConference()");
        }
        
        if (activity == null) {
            Log.e(TAG, "startConference failed: activity is null");
            return;
        }
        if (options == null) {
            options = new ConferenceOptions.Builder().build();
        }

        Log.i(TAG, "startConference options: " + options.toString());

        Intent intent = new Intent(activity, FlutterDemoActivity.class);
        intent.putExtra("route", options.getRoute());
        
        Map<String, Object> args = options.getArguments();
        Log.i(TAG, "startConference arguments: " + args);
        if (args != null && !args.isEmpty()) {
            Bundle argsBundle = new Bundle();
            argsBundle.putSerializable("arguments", (Serializable) args);
            intent.putExtra("arguments_bundle", argsBundle);
        }
        activity.startActivity(intent);
    }

    /**
     * 启动会议并传递参数 (旧版接口，建议迁移)
     *
     * @param activity 当前宿主 Activity
     * @param route 目标 Flutter 路由 (例如 "/call")
     * @param arguments 路由参数 (Map)
     */
    @Deprecated
    public static void startConference(Activity activity, String route, Map<String, Object> arguments) {
        ConferenceOptions.Builder builder = new ConferenceOptions.Builder()
                .setRoute(route);
        if (arguments != null) {
            for (Map.Entry<String, Object> entry : arguments.entrySet()) {
                builder.addArgument(entry.getKey(), entry.getValue());
            }
        }
        startConference(activity, builder.build());
    }

    /**
     * 停止会议并退出页面
     */
    public static void stopConference() {
        SDLActivityAdapter.StopConference();
    }

    /**
     * 群组拍照（前置摄像头）
     * @param fileName 文件名（不带扩展名）
     * @param listener 拍照回调
     */
    public static void businessPhotoForGroup(String fileName, OnBusinessPhotoTakeListener listener) {
        SDLActivityAdapter.BusinessPhotoForGroup(fileName, true, listener);
    }

    /**
     * 单人拍照（后置摄像头）
     * @param fileName 文件名（不带扩展名）
     * @param toggleCamera 是否切换到后置摄像头
     * @param tipsContent 确认框提示内容（仅toggleCamera=true时有效）
     * @param listener 拍照回调
     */
    public static void businessPhotoForSingle(String fileName, boolean toggleCamera, String tipsContent, OnBusinessPhotoTakeListener listener) {
        SDLActivityAdapter.BusinessPhotoForSingle(fileName, toggleCamera, tipsContent, listener);
    }

    /**
     * @deprecated 请使用 businessPhotoForGroup 代替
     */
    @Deprecated
    public static void startBusinessPhotoMode() {
        SDLActivityAdapter.StartBusinessPhotoMode();
    }

    /**
     * @deprecated 请使用 businessPhotoForGroup 或 businessPhotoForSingle 代替
     */
    @Deprecated
    public static void stopBusinessPhotoMode() {
        SDLActivityAdapter.StopBusinessPhotoMode();
    }

    /**
     * 发送消息（通过 transportInner）
     * @param message JSON 字符串格式的消息
     */
    public static void sendMessage(String message) {
        SDLActivityAdapter.SendMessage(message);
    }

    /**
     * 添加事件监听器 (线程安全，自动分发到主线程)
     * 优化：确保每个调用者类型只注册一次，防止重入导致的日志重复
     */
    public static void addEventListener(@NonNull XChatEventListener listener) {
        if (listener == null) return;
        
        if (!isInitialized) {
            Log.w(TAG, "addEventListener() called before init(). Listener will be queued but SDK may not be ready.");
        }
        
        // 1. 先移除同类型的旧监听器 (防止 MainActivity/Service 重入导致重复)
        for (XChatEventListener l : listeners) {
            if (l.getClass().getName().equals(listener.getClass().getName())) {
                Log.w(TAG, "Listener of type " + listener.getClass().getName() + " already added. Removing old one and adding new.");
                listeners.remove(l);
                break;
            }
        }
        
        // 2. 添加新监听器
        listeners.add(listener);
        ensureAdapterListener();
    }

    /**
      * 移除事件监听器
      */
    public static void removeEventListener(XChatEventListener listener) {
        if (listener == null) return;
        
        if (!isInitialized) {
            Log.w(TAG, "removeEventListener() called before init().");
        }
        
        // 双重匹配：实例匹配或类名匹配 (防止匿名类导致无法移除)
        for (XChatEventListener l : listeners) {
            if (l == listener || l.getClass().getName().equals(listener.getClass().getName())) {
                listeners.remove(l);
            }
        }
    }

    /**
     * (已废弃) 请使用 addEventListener / removeEventListener
     */
    @Deprecated
    public static void setEventListener(XChatEventListener listener) {
        if (listener == null) {
            listeners.clear();
        } else {
            addEventListener(listener);
        }
    }

    private static void ensureAdapterListener() {
        if (isAdapterListenerSet) return;
        
        SDLActivityAdapter.SetCallEventListener(new SDLActivityAdapter.CallEventListener() {
            @Override
            public void onMessage(String msgtype, String message, String time) {
                // 确保在主线程分发
                mainHandler.post(() -> {
                    for (XChatEventListener l : listeners) {
                        l.onMessage(msgtype, message, time);
                    }
                });
            }

            @Override
            public void onReceiveMessage(String message) {
                mainHandler.post(() -> {
                    for (XChatEventListener l : listeners) {
                        l.onReceiveMessage(message);
                    }
                });
            }

            @Override
            public void onPhotoCaptured(byte[] data) {
                // 确保在主线程分发
                mainHandler.post(() -> {
                    for (XChatEventListener l : listeners) {
                        l.onPhotoCaptured(data);
                    }
                });
            }
        });
        isAdapterListenerSet = true;
    }

    /**
     * 拍照
     */
    public static byte[] takePhoto(String peerId) {
        return SDLActivityAdapter.TakePhoto(peerId);
    }

    /**
     * 销毁 SDK 资源
     */
    public static void destroy() {
        SDLActivityAdapter.DestroyXChatKit();
        
        // 清理缓存的 Flutter 引擎
        SDLActivityAdapter.clearCachedEngine(ENGINE_ID);
        
        listeners.clear();
        isAdapterListenerSet = false;
        isInitialized = false;
        isEnginePrewarmed = false;
        prewarmListener = null;
        Log.i(TAG, "XChatKit destroyed.");
    }
}
````

## File: rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatKitConfig.java
````java
package com.yc.rtc.rsc_sdk;

import android.content.Context;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;

/**
 * XChatKit 配置管理类
 * 从 assets 目录读取统一配置文件
 */
public class XChatKitConfig {
    private UserData userData;
    private MediaInfo mediaInfo;

    public UserData getUserData() {
        return userData;
    }

    public MediaInfo getMediaInfo() {
        return mediaInfo;
    }

    /**
     * 媒体信息类
     */
    public static class MediaInfo {
        private String mediaEntranceUrl;
        private String mgwUrl;
        private String picUrl;
        private String roomMode;
        private String roomId;
        private String peerId;
        private String peerType;
        private String iceServers; // JSON 字符串
        private String aCenter; // 主中心地址（格式：ip:port）
        private String bCenter; // 备用中心地址（格式：ip:port）
        private String probe; // 探测路径（如 "/probe"）

        public String getMediaEntranceUrl() {
            return mediaEntranceUrl != null ? mediaEntranceUrl : "";
        }

        public void setMediaEntranceUrl(String mediaEntranceUrl) {
            this.mediaEntranceUrl = mediaEntranceUrl;
        }

        public String getMgwUrl() {
            return mgwUrl != null ? mgwUrl : "";
        }

        public void setMgwUrl(String mgwUrl) {
            this.mgwUrl = mgwUrl;
        }

        public String getRoomMode() {
            return roomMode != null ? roomMode : "";
        }

        public void setRoomMode(String roomMode) {
            this.roomMode = roomMode;
        }

        public String getRoomId() {
            return roomId != null ? roomId : "";
        }

        public void setRoomId(String roomId) {
            this.roomId = roomId;
        }

        public String getPeerId() {
            return peerId != null ? peerId : "";
        }

        public void setPeerId(String peerId) {
            this.peerId = peerId;
        }

        public String getPeerType() {
            return peerType != null ? peerType : "";
        }

        public void setPeerType(String peerType) {
            this.peerType = peerType;
        }

        public String getIceServers() {
            return iceServers != null ? iceServers : "";
        }

        public void setIceServers(String iceServers) {
            this.iceServers = iceServers;
        }

        public String getACenter() {
            return aCenter != null ? aCenter : "";
        }

        public void setACenter(String aCenter) {
            this.aCenter = aCenter;
        }

        public String getBCenter() {
            return bCenter != null ? bCenter : "";
        }

        public void setBCenter(String bCenter) {
            this.bCenter = bCenter;
        }

        public String getPicUrl() {
            return picUrl != null ? picUrl : "";
        }

        public void setPicUrl(String picUrl) {
            this.picUrl = picUrl;
        }

        public String getProbe() {
            return probe != null ? probe : "";
        }

        public void setProbe(String probe) {
            this.probe = probe;
        }

        /**
         * 转换为 JSONObject
         */
        public JSONObject toJSONObject() throws JSONException {
            JSONObject json = new JSONObject();
            json.put("mediaEntranceUrl", getMediaEntranceUrl());
            json.put("mgwUrl", getMgwUrl());
            json.put("roomMode", getRoomMode());
            json.put("roomId", getRoomId());
            json.put("peerId", getPeerId());
            json.put("peerType", getPeerType());
            json.put("aCenter", getACenter());
            json.put("bCenter", getBCenter());
            json.put("probe", getProbe());
            
            // iceServers 保持原始 JSON 格式
            if (iceServers != null && !iceServers.isEmpty()) {
                json.put("iceServers", new JSONObject(iceServers).get("iceServers"));
            }
            
            return json;
        }

        /**
         * 从 JSONObject 创建
         */
        public static MediaInfo fromJSONObject(JSONObject json) {
            MediaInfo mediaInfo = new MediaInfo();
            if (json == null) {
                return mediaInfo;
            }
            mediaInfo.setMediaEntranceUrl(json.optString("mediaEntranceUrl", ""));
            mediaInfo.setMgwUrl(json.optString("mgwUrl", ""));
            mediaInfo.setRoomMode(json.optString("roomMode", ""));
            mediaInfo.setRoomId(json.optString("roomId", ""));
            mediaInfo.setPeerId(json.optString("peerId", ""));
            mediaInfo.setPeerType(json.optString("peerType", ""));
            mediaInfo.setACenter(json.optString("aCenter", ""));
            mediaInfo.setBCenter(json.optString("bCenter", ""));
            mediaInfo.setProbe(json.optString("probe", ""));
            
            // 保存 iceServers 的 JSON 字符串
            if (json.has("iceServers")) {
                try {
                    JSONObject iceServersWrapper = new JSONObject();
                    iceServersWrapper.put("iceServers", json.get("iceServers"));
                    mediaInfo.setIceServers(iceServersWrapper.toString());
                } catch (JSONException e) {
                    e.printStackTrace();
                }
            }

            return mediaInfo;
        }
    }

    /**
     * 从 assets 配置文件加载配置
     * 
     * @param context 上下文
     * @param configFileName 配置文件名（默认 "xchatkit_config.json"）
     * @return XChatKitConfig 配置对象
     */
    public static XChatKitConfig fromAssetsConfig(Context context, String configFileName) 
            throws IOException, JSONException {
        // 读取配置文件
        InputStream is = context.getAssets().open(configFileName);
        int size = is.available();
        byte[] buffer = new byte[size];
        is.read(buffer);
        is.close();
        String json = new String(buffer, "UTF-8");

        // 解析 JSON
        JSONObject rootJson = new JSONObject(json);
        
        XChatKitConfig config = new XChatKitConfig();
        
        // 解析 user_data
        if (rootJson.has("userData")) {
            JSONObject userDataJson = rootJson.getJSONObject("userData");
            config.userData = UserData.fromJSONObject(userDataJson);
        } else {
            config.userData = new UserData();
        }
        
        // 解析 mediaInfo
        if (rootJson.has("mediaInfo")) {
            JSONObject mediaInfoJson = rootJson.getJSONObject("mediaInfo");
            config.mediaInfo = MediaInfo.fromJSONObject(mediaInfoJson);
        } else {
            config.mediaInfo = new MediaInfo();
        }
        
        return config;
    }

    /**
     * 从默认配置文件加载
     */
    public static XChatKitConfig fromAssetsConfig(Context context) 
            throws IOException, JSONException {
        return fromAssetsConfig(context, "xchatkit_config.json");
    }
}
````

## File: rsc-sdk/src/main/java/com/yc/rtc/rsc_sdk/XChatLifecycleObserver.java
````java
package com.yc.rtc.rsc_sdk;

import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.LifecycleOwner;
import android.util.Log;

import androidx.annotation.NonNull;

/**
 * 自动管理 XChatKit 生命周期的观察者
 */
public class XChatLifecycleObserver implements DefaultLifecycleObserver {

    @Override
    public void onDestroy(@NonNull LifecycleOwner owner) {
        Log.i("XChatLifecycle", "Host onDestroy: Releasing XChatKit resources...");
        XChatKit.destroy();
    }
}
````

## File: rsc-sdk/src/main/AndroidManifest.xml
````xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    package="com.yc.rtc.rsc_sdk">

    <!-- 声明必要的权限 (虽然 Flutter 模块可能已经声明了，但为了健壮性这里也声明) -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <application>
        <!-- 声明 SDK 内置的 FlutterActivity -->
        <activity
            android:name=".FlutterDemoActivity"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:exported="false"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar"
            android:supportsPictureInPicture="true"
            android:resizeableActivity="true"
            android:launchMode="singleTop"/>
        <!-- Android 14+ 屏幕共享需要前台服务 -->
        <!-- flutter_foreground_task 插件的前台服务声明 -->
        <!-- 注意：即使 AAR 中可能包含此声明，在宿主应用中显式声明可以确保服务正常工作 -->
        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="mediaProjection"
            android:stopWithTask="true"
            tools:ignore="MissingClass" />
    </application>

</manifest>
````

## File: rsc-sdk/src/test/java/com/yc/rtc/rsc_sdk/ExampleUnitTest.java
````java
package com.yc.rtc.rsc_sdk;

import org.junit.Test;

import static org.junit.Assert.*;

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
public class ExampleUnitTest {
    @Test
    public void addition_isCorrect() {
        assertEquals(4, 2 + 2);
    }
}
````

## File: rsc-sdk/.gitignore
````
/build
````

## File: rsc-sdk/.project
````
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
	<name>rsc-sdk</name>
	<comment>Project rsc-sdk created by Buildship.</comment>
	<projects>
	</projects>
	<buildSpec>
		<buildCommand>
			<name>org.eclipse.buildship.core.gradleprojectbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
	</buildSpec>
	<natures>
		<nature>org.eclipse.buildship.core.gradleprojectnature</nature>
	</natures>
	<filteredResources>
		<filter>
			<id>1773017193443</id>
			<name></name>
			<type>30</type>
			<matcher>
				<id>org.eclipse.core.resources.regexFilterMatcher</id>
				<arguments>node_modules|\.git|__CREATED_BY_JAVA_LANGUAGE_SERVER__</arguments>
			</matcher>
		</filter>
	</filteredResources>
</projectDescription>
````

## File: rsc-sdk/build.gradle
````
plugins {
    alias(libs.plugins.android.library)
    id 'maven-publish'
}

android {
    namespace 'com.yc.rtc.rsc_sdk'
    compileSdk 35

    defaultConfig {
        minSdk 29

        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles "consumer-rules.pro"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        profile {
            initWith debug
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    // 确保发布时包含 AAR 变体
    publishing {
        singleVariant("release")
    }
}

afterEvaluate {
    publishing {
        publications {
            release(MavenPublication) {
                from components.release
                groupId = 'com.yc.rtc'
                artifactId = 'rtc-sdk'
                version = '1.0.0'
            }
        }
        repositories {
            maven {
                // 指向 Flutter AAR 生成的本地仓库路径 (请根据实际路径调整)
                url = layout.projectDirectory.dir("../../flutter_module/build/host/outputs/repo")
            }
        }
    }
}

dependencies {

    implementation libs.appcompat
    implementation libs.material
    testImplementation libs.junit
    androidTestImplementation libs.ext.junit
    androidTestImplementation libs.espresso.core

    // Lifecycle components
    implementation "androidx.lifecycle:lifecycle-common:2.6.2"

    compileOnly 'com.yc.rtc.flutter_module:flutter_debug:1.0'
    compileOnly 'com.yc.rtc.flutter_module:flutter_profile:1.0'
    compileOnly 'com.yc.rtc.flutter_module:flutter_release:1.0'
    // 添加 provider_sdk.jar 依赖
//    implementation files('../lib/provider_sdk.jar')
}
````

## File: rsc-sdk/consumer-rules.pro
````
# XChatKit SDK 核心类保持
-keep class com.yc.rtc.rsc_sdk.** { *; }

# 保持序列化类，防止 Intent 传参失败
-keep class com.yc.rtc.rsc_sdk.ConferenceOptions { *; }
-keep class com.yc.rtc.rsc_sdk.ConferenceOptions$Builder { *; }

# 保持 Flutter 适配器与桥接类 (反射调用)
-keep class com.yc.rtc.rsc_sdk.SDLActivityAdapter { *; }
-keep class com.yc.rtc.rsc_sdk.SDLActivityAdapter$CallEventListener { *; }

# 保持 AndroidX 生命周期组件引用
-keep class androidx.lifecycle.LifecycleOwner { *; }
-keep class androidx.lifecycle.Lifecycle { *; }

# Flutter 引擎通用规则
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
````

## File: rsc-sdk/INTEGRATION_GUIDE.md
````markdown
# XChatKit SDK 离线集成指南

本文档说明如何将 `xchat-sdk` 和 `flutter_module` 以 AAR 形式集成到现有的 Android 原生工程中。

## 1. 准备工作

请确保你已经获取了以下两个 AAR 文件：
1.  `xchat-sdk-release.aar`: 包含了原生桥接代码和 API 接口。
2.  `flutter_module-release.aar`: 包含了 Flutter 引擎和业务代码。

## 2. 工程配置

### 2.1 添加 AAR 依赖

将上述两个 AAR 文件放入你主工程模块（例如 `app`）的 `libs` 目录下。

修改 `app/build.gradle`：

```groovy
dependencies {
    // 引入本地 AAR
    implementation files('libs/xchat-sdk-release.aar')
    implementation files('libs/flutter_module-release.aar')

    // 必须添加 Flutter 引擎依赖 (版本需与 AAR 构建版本一致)
    // 示例使用 release 版本
    implementation 'io.flutter:flutter_embedding_release:1.0.0-xxxxxxxxxxxxxxxx' 
    // 或者使用 debug 版本用于调试
    // implementation 'io.flutter:flutter_embedding_debug:1.0.0-xxxxxxxxxxxxxxxx'
    
    // 引入 SDK 依赖的第三方库 (如果 AAR 未包含)
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.gsc.provider:sdk:1.0.0' // 根据实际情况调整
    
    // 其他必要依赖
    implementation 'com.google.code.gson:gson:2.10.1' // 如果使用 Gson 处理 JSON
}
```

### 2.2 配置 AndroidManifest.xml

SDK 内部已经声明了必要的 Activity，通常不需要在宿主 App 中重复声明。
但请确保合并后的 Manifest 包含以下权限（SDK 已声明，合并即可）：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<!-- ... 其他权限 ... -->
```

## 3. 接口调用

统一入口类为 `com.yc.rtc.rsc_sdk.XChatKit`。

### 3.1 初始化 (建议在 Application 中调用)

在你的 `Application.onCreate()` 中调用初始化方法，可以提前加载 Flutter 引擎，显著提升入会页面的打开速度。

```java
import com.yc.rtc.rsc_sdk.XChatKit;

public class MyApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        // 初始化 SDK
        XChatKit.init(this);
    }
}
```

### 3.2 设置用户数据

在启动会议前，**必须**设置用户数据。数据格式为 JSON 字符串。

```java
JSONObject userData = new JSONObject();
// 构建符合规范的 JSON 数据
userData.put("mediaEntranceUrl", "...");
userData.put("roomId", "12345");
userData.put("peerId", "user_001");
// ... 更多字段 ...

XChatKit.setUserData(userData.toString());
```

**JSON 参数说明：**

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `mediaEntranceUrl` | String | 媒体入口地址 |
| `mgwUrl` | String | MGW 地址 |
| `roomId` | String | 房间号 |
| `peerId` | String | 用户 ID |
| `peerType` | String | 用户类型 |
| `proxyIp` | String | (可选) 代理 IP |
| `proxyPort` | Int | (可选) 代理端口 |

### 3.3 监听事件回调

注册监听器以接收会议状态变更事件。

```java
XChatKit.setEventListener(new XChatKit.CallEventListener() {
    @Override
    public void onMessage(String msgtype, String message) {
        Log.d("SDK_EVENT", "Type: " + msgtype + ", Msg: " + message);
        
        // 常见 msgtype:
        // "EventJoinSucc": 入会成功
        // "EventReleased": 通话结束/释放
        // "EventSocketError": 连接错误
    }
});
```

### 3.4 启动会议

```java
XChatKit.startConference(currentActivity);
```

此方法会启动 SDK 内置的 `FlutterDemoActivity` 并加载会议界面。

### 3.5 高级功能：拍照

```java
// 拍摄对方画面 (peerId) 或 本地画面 (null)
byte[] photoData = XChatKit.takePhoto(targetPeerId);

if (photoData != null) {
    Bitmap bitmap = BitmapFactory.decodeByteArray(photoData, 0, photoData.length);
    // 显示图片
}
```

### 3.6 销毁资源

在应用退出或确定不再使用 SDK 时调用。

```java
XChatKit.destroy();
```

## 4. 特殊配置说明

### 4.1 画中画 (Picture-in-Picture)

如果你需要支持画中画功能，请在你的 `AndroidManifest.xml` 中对 `FlutterDemoActivity` 进行属性覆盖（通常 SDK 已包含，但你可以根据需求调整）：

```xml
<activity
    android:name="com.yc.rtc.rsc_sdk.FlutterDemoActivity"
    android:supportsPictureInPicture="true"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    tools:replace="android:supportsPictureInPicture" />
```

### 4.2 屏幕共享 (Android 14+)

对于 Android 14 及以上版本，屏幕共享需要声明前台服务。请在宿主 Manifest 中添加：

```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="mediaProjection"
    android:exported="false" />
```

## 5. 混淆规则 (ProGuard)

如果主工程开启了混淆，请添加以下规则以保留 SDK 接口：

```proguard
-keep class com.yc.rtc.rsc_sdk.** { *; }
-keep class io.flutter.** { *; }
```

## 6. 最佳实践与错误处理

### 6.1 初始化顺序

请确保按以下顺序调用 SDK：

```java
public class MyApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        // 1. 首先初始化 SDK
        XChatKit.init(this);
    }
}

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // 2. 设置事件监听器
        XChatKit.addEventListener(eventListener);
        
        // 3. 可选：绑定生命周期（自动管理 destroy）
        XChatKit.bindLifecycle(this);
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        // 移除监听器（如果未使用 bindLifecycle）
        XChatKit.removeEventListener(eventListener);
    }
}
```

### 6.2 错误处理

SDK 在检测到不正确的使用时会输出警告日志或抛出异常：

| 场景 | 行为 |
|------|------|
| `重复调用 | init()` 警告日志，不重复初始化 |
| `startConference()` 前未调用 `init()` | 抛出 `IllegalStateException` |
| `addEventListener()` 前未调用 `init()` | 警告日志，监听器会被加入队列 |
| 重复添加同类型监听器 | 警告日志，自动替换旧监听器 |

### 6.3 生命周期管理

推荐使用 `bindLifecycle()` 自动管理 SDK 生命周期：

```java
XChatKit.bindLifecycle(this);
```

这样在宿主 Activity/Fragment 销毁时，SDK 会自动调用 `destroy()` 释放资源。
````

## File: rsc-sdk/proguard-rules.pro
````
# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile
````

## File: .gitignore
````
*.iml
.gradle
/local.properties
/.idea/caches
/.idea/libraries
/.idea/modules.xml
/.idea/workspace.xml
/.idea/navEditor.xml
/.idea/assetWizardSettings.xml
.DS_Store
/build
/captures
.externalNativeBuild
.cxx
local.properties
````

## File: build.gradle
````
// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
}
````

## File: gradle.properties
````
# Project-wide Gradle settings.
# IDE (e.g. Android Studio) users:
# Gradle settings configured through the IDE *will override*
# any settings specified in this file.
# For more details on how to configure your build environment visit
# http://www.gradle.org/docs/current/userguide/build_environment.html
# Specifies the JVM arguments used for the daemon process.
# The setting is particularly useful for tweaking memory settings.
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
# When configured, Gradle will run in incubating parallel mode.
# This option should only be used with decoupled projects. For more details, visit
# https://developer.android.com/r/tools/gradle-multi-project-decoupled-projects
# org.gradle.parallel=true
# AndroidX package structure to make it clearer which packages are bundled with the
# Android operating system, and which are packaged with your app's APK
# https://developer.android.com/topic/libraries/support-library/androidx-rn
android.useAndroidX=true
# Enables namespacing of each library's R class so that its R class includes only the
# resources declared in the library itself and none from the library's dependencies,
# thereby reducing the size of the R class for that library
android.nonTransitiveRClass=true
````

## File: gradlew
````
#!/usr/bin/env sh

#
# Copyright 2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

##############################################################################
##
##  Gradle start up script for UN*X
##
##############################################################################

# Attempt to set APP_HOME
# Resolve links: $0 may be a link
PRG="$0"
# Need this for relative symlinks.
while [ -h "$PRG" ] ; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '/.*' > /dev/null; then
        PRG="$link"
    else
        PRG=`dirname "$PRG"`"/$link"
    fi
done
SAVED="`pwd`"
cd "`dirname \"$PRG\"`/" >/dev/null
APP_HOME="`pwd -P`"
cd "$SAVED" >/dev/null

APP_NAME="Gradle"
APP_BASE_NAME=`basename "$0"`

# Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
DEFAULT_JVM_OPTS='"-Xmx64m" "-Xms64m"'

# Use the maximum available, or set MAX_FD != -1 to use that value.
MAX_FD="maximum"

warn () {
    echo "$*"
}

die () {
    echo
    echo "$*"
    echo
    exit 1
}

# OS specific support (must be 'true' or 'false').
cygwin=false
msys=false
darwin=false
nonstop=false
case "`uname`" in
  CYGWIN* )
    cygwin=true
    ;;
  Darwin* )
    darwin=true
    ;;
  MINGW* )
    msys=true
    ;;
  NONSTOP* )
    nonstop=true
    ;;
esac

CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar


# Determine the Java command to use to start the JVM.
if [ -n "$JAVA_HOME" ] ; then
    if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
        # IBM's JDK on AIX uses strange locations for the executables
        JAVACMD="$JAVA_HOME/jre/sh/java"
    else
        JAVACMD="$JAVA_HOME/bin/java"
    fi
    if [ ! -x "$JAVACMD" ] ; then
        die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
    fi
else
    JAVACMD="java"
    which java >/dev/null 2>&1 || die "ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
fi

# Increase the maximum file descriptors if we can.
if [ "$cygwin" = "false" -a "$darwin" = "false" -a "$nonstop" = "false" ] ; then
    MAX_FD_LIMIT=`ulimit -H -n`
    if [ $? -eq 0 ] ; then
        if [ "$MAX_FD" = "maximum" -o "$MAX_FD" = "max" ] ; then
            MAX_FD="$MAX_FD_LIMIT"
        fi
        ulimit -n $MAX_FD
        if [ $? -ne 0 ] ; then
            warn "Could not set maximum file descriptor limit: $MAX_FD"
        fi
    else
        warn "Could not query maximum file descriptor limit: $MAX_FD_LIMIT"
    fi
fi

# For Darwin, add options to specify how the application appears in the dock
if $darwin; then
    GRADLE_OPTS="$GRADLE_OPTS \"-Xdock:name=$APP_NAME\" \"-Xdock:icon=$APP_HOME/media/gradle.icns\""
fi

# For Cygwin or MSYS, switch paths to Windows format before running java
if [ "$cygwin" = "true" -o "$msys" = "true" ] ; then
    APP_HOME=`cygpath --path --mixed "$APP_HOME"`
    CLASSPATH=`cygpath --path --mixed "$CLASSPATH"`

    JAVACMD=`cygpath --unix "$JAVACMD"`

    # We build the pattern for arguments to be converted via cygpath
    ROOTDIRSRAW=`find -L / -maxdepth 1 -mindepth 1 -type d 2>/dev/null`
    SEP=""
    for dir in $ROOTDIRSRAW ; do
        ROOTDIRS="$ROOTDIRS$SEP$dir"
        SEP="|"
    done
    OURCYGPATTERN="(^($ROOTDIRS))"
    # Add a user-defined pattern to the cygpath arguments
    if [ "$GRADLE_CYGPATTERN" != "" ] ; then
        OURCYGPATTERN="$OURCYGPATTERN|($GRADLE_CYGPATTERN)"
    fi
    # Now convert the arguments - kludge to limit ourselves to /bin/sh
    i=0
    for arg in "$@" ; do
        CHECK=`echo "$arg"|egrep -c "$OURCYGPATTERN" -`
        CHECK2=`echo "$arg"|egrep -c "^-"`                                 ### Determine if an option

        if [ $CHECK -ne 0 ] && [ $CHECK2 -eq 0 ] ; then                    ### Added a condition
            eval `echo args$i`=`cygpath --path --ignore --mixed "$arg"`
        else
            eval `echo args$i`="\"$arg\""
        fi
        i=`expr $i + 1`
    done
    case $i in
        0) set -- ;;
        1) set -- "$args0" ;;
        2) set -- "$args0" "$args1" ;;
        3) set -- "$args0" "$args1" "$args2" ;;
        4) set -- "$args0" "$args1" "$args2" "$args3" ;;
        5) set -- "$args0" "$args1" "$args2" "$args3" "$args4" ;;
        6) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" ;;
        7) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" ;;
        8) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" "$args7" ;;
        9) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" "$args7" "$args8" ;;
    esac
fi

# Escape application args
save () {
    for i do printf %s\\n "$i" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/' \\\\/" ; done
    echo " "
}
APP_ARGS=`save "$@"`

# Collect all arguments for the java command, following the shell quoting and substitution rules
eval set -- $DEFAULT_JVM_OPTS $JAVA_OPTS $GRADLE_OPTS "\"-Dorg.gradle.appname=$APP_BASE_NAME\"" -classpath "\"$CLASSPATH\"" org.gradle.wrapper.GradleWrapperMain "$APP_ARGS"

exec "$JAVACMD" "$@"
````

## File: gradlew.bat
````batch
@rem
@rem Copyright 2015 the original author or authors.
@rem
@rem Licensed under the Apache License, Version 2.0 (the "License");
@rem you may not use this file except in compliance with the License.
@rem You may obtain a copy of the License at
@rem
@rem      https://www.apache.org/licenses/LICENSE-2.0
@rem
@rem Unless required by applicable law or agreed to in writing, software
@rem distributed under the License is distributed on an "AS IS" BASIS,
@rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
@rem See the License for the specific language governing permissions and
@rem limitations under the License.
@rem

@if "%DEBUG%" == "" @echo off
@rem ##########################################################################
@rem
@rem  Gradle startup script for Windows
@rem
@rem ##########################################################################

@rem Set local scope for the variables with windows NT shell
if "%OS%"=="Windows_NT" setlocal

set DIRNAME=%~dp0
if "%DIRNAME%" == "" set DIRNAME=.
set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%

@rem Resolve any "." and ".." in APP_HOME to make it shorter.
for %%i in ("%APP_HOME%") do set APP_HOME=%%~fi

@rem Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"

@rem Find java.exe
if defined JAVA_HOME goto findJavaFromJavaHome

set JAVA_EXE=java.exe
%JAVA_EXE% -version >NUL 2>&1
if "%ERRORLEVEL%" == "0" goto execute

echo.
echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
echo.
echo Please set the JAVA_HOME variable in your environment to match the
echo location of your Java installation.

goto fail

:findJavaFromJavaHome
set JAVA_HOME=%JAVA_HOME:"=%
set JAVA_EXE=%JAVA_HOME%/bin/java.exe

if exist "%JAVA_EXE%" goto execute

echo.
echo ERROR: JAVA_HOME is set to an invalid directory: %JAVA_HOME%
echo.
echo Please set the JAVA_HOME variable in your environment to match the
echo location of your Java installation.

goto fail

:execute
@rem Setup the command line

set CLASSPATH=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar


@rem Execute Gradle
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=%APP_BASE_NAME%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*

:end
@rem End local scope for the variables with windows NT shell
if "%ERRORLEVEL%"=="0" goto mainEnd

:fail
rem Set variable GRADLE_EXIT_CONSOLE if you need the _script_ return code instead of
rem the _cmd.exe /c_ return code!
if  not "" == "%GRADLE_EXIT_CONSOLE%" exit 1
exit /b 1

:mainEnd
if "%OS%"=="Windows_NT" endlocal

:omega
````

## File: settings.gradle
````
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    String storageUrl = System.env.FLUTTER_STORAGE_BASE_URL ?: "https://storage.googleapis.com"

    repositories {
        google()
        mavenCentral()
        // Flutter Module AAR 本地仓库
        maven {
            url '/Users/wangxinran/StudioProjects/flutter_module/build/host/outputs/repo'
        }
        // Flutter 官方仓库
        maven {
            url "$storageUrl/download.flutter.io"
        }
        // JitPack 仓库
        maven { 
            url 'https://jitpack.io'
        }
    }
}

rootProject.name = "My Application For Flutter"
include ':app'
include ':rsc-sdk'
````
