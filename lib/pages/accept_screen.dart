import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mime/mime.dart';
import 'package:my_http/util/HttpServerTaskHandler%20.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class AcceptScreen extends StatefulWidget {
  const AcceptScreen({super.key});

  @override
  State<AcceptScreen> createState() => _AcceptScreenState();
}

class _AcceptScreenState extends State<AcceptScreen> {
  //追踪请求
  final Set<HttpRequest> _activeRequests = {}; // 新增
  late HttpServer? _server;
  List<String> _serverStatus = [];
  // 新增状态变量
  final StreamController<UploadProgress> _progressController =
      StreamController<UploadProgress>.broadcast();
  String? _currentUploadFile;
  int _totalBytes = 0;
  int _receivedBytes = 0;

  //检查前台权限
  Future<void> _requestPermissions() async {
    // 如果是 Windows 或 Web，直接跳过
    if (kIsWeb || Platform.isWindows) return;
    // Android 13+, you need to allow notification permission to display foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      // Android 12+, there are restrictions on starting a foreground service.
      //
      // To restart the service on device reboot or unexpected problem, you need to allow below permission.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      // Use this utility only if you provide services that require long-term survival,
      // such as exact alarm service, healthcare service, or Bluetooth communication.
      //
      // This utility requires the "android.permission.SCHEDULE_EXACT_ALARM" permission.
      // Using this permission may make app distribution difficult due to Google policy.
      /*  if (!await FlutterForegroundTask.canScheduleExactAlarms) {
        // When you call this function, will be gone to the settings page.
        // So you need to explain to the user why set it.
        await FlutterForegroundTask.openAlarmsAndRemindersSettings();
      } */
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription: '前台服务正在运行中',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  void initState() {
    // 仅在移动端导入插件

    // TODO: implement initState
    super.initState();
    // 仅移动端初始化插件通信
    if (!kIsWeb && !Platform.isWindows) {
      // Add a callback to receive data sent from the TaskHandler.
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Request permissions and initialize the service.
        _requestPermissions();
        _initService();
      });
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map<String, dynamic>) {
      final dynamic timestampMillis = data["timestampMillis"];
      if (timestampMillis != null) {
        final DateTime timestamp =
            DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true);
        print('timestamp: ${timestamp.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            // 上传进度显示
            StreamBuilder<UploadProgress>(
              stream: _progressController.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: LinearProgressIndicator(
                          value: snapshot.data!.total > 0
                              ? snapshot.data!.received / snapshot.data!.total
                              : null,
                          minHeight: 12,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(Colors.blue),
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      Text(
                        "${snapshot.data!.fileName}\n"
                        "${_formatBytes(snapshot.data!.received)}/"
                        "${_formatBytes(snapshot.data!.total)}",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }
                return const SizedBox(height: 40);
              },
            ),
            OutlinedButton(onPressed: start, child: Text("开启接受")),
            OutlinedButton(onPressed: stop, child: Text("关闭接受")),

            // 原状态列表
            Expanded(
              child: ListView.builder(
                itemCount: _serverStatus.length,
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(_serverStatus[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<ServiceRequestResult> _startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '服务器正在运行中',
        notificationText: '',
        notificationIcon:
            NotificationIcon(metaDataName: 'tz', backgroundColor: Colors.blue),
        notificationButtons: [
          //const NotificationButton(id: 'stop', text: '暂停'),
        ],
        notificationInitialRoute: '/',
        callback: startCallback,
      );
    }
  }

  Future<ServiceRequestResult> stopService() {
    return FlutterForegroundTask.stopService();
  }

  Future<void> start() async {
    try {
      _printLocalIP();
      //这行代码会创建一个 HTTP 服务器实例，并绑定到指定的网络地址和端口，等待接收客户端的请求。允许局域网内的其他设备通过 IP 地址访问。
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      _server?.listen((request) => _handleRequest(request));
      print("服务器已启动");

      setState(() {
        _serverStatus.add("服务器已启动");
        if (!kIsWeb && !Platform.isWindows) {
          _startService();
        }
      });
    } catch (e) {
      setState(() {
        _serverStatus.add("启动失败: $e");
      });
      print("启动失败: $e");
    }
  }

  void stop() {
    // 强制终止所有活动请求
    for (final request in _activeRequests) {
      request.response.detachSocket().then((socket) => socket.destroy());
    }
    _activeRequests.clear();

    // 强制关闭服务器
    _server?.close(force: true); // 使用 force: true 立即释放端口
    _server = null;

    setState(() {
      _resetUploadState(); // 重置进度显示
      //  _serverStatus.add("服务器已强制关闭");
      _serverStatus.add("服务器已关闭，所有传输已中断");
      if (!kIsWeb && !Platform.isWindows) {
        stopService();
      }
    });
  }

  void _printLocalIP() async {
    final interfaces = await NetworkInterface.list();
    interfaces.forEach((interface) {
      interface.addresses.forEach((addr) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          print('可用IP: ${addr.address}');
          setState(() {
            _serverStatus.add('本机IP: ${addr.address}:8080');
          });
        }
      });
    });
  }

  void _handleRequest(HttpRequest request) async {
    _activeRequests.add(request); // 注册请求
    if (request.method == 'POST' && request.uri.path == '/upload') {
      try {
        setState(() {
          _totalBytes = request.contentLength;
          _receivedBytes = 0;
        });

        var transformer = MimeMultipartTransformer(
            request.headers.contentType?.parameters['boundary'] ?? '');

        // 定义保存目录（确保可写）
        final directory = Directory('/zuimo');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        await for (var part in transformer.bind(request)) {
          // 从 Content-Disposition 头部解析文件名
          String? fileName;
          final contentDisposition = part.headers['content-disposition'];
          if (contentDisposition != null) {
            final regex = RegExp(r'filename="([^"]+)"');
            final match = regex.firstMatch(contentDisposition);
            if (match != null) {
              fileName = match.group(1);
            }
          }
          fileName ??= 'unknown_file';

          // 生成唯一文件名避免冲突
          final uniqueFileName =
              '$fileName';
          // 安全拼接路径
          final filePath = '${directory.path}/${path.basename(uniqueFileName)}';

          final file = File(filePath);
          final sink = file.openWrite();

          await for (final chunk in part.cast<List<int>>()) {
            sink.add(chunk);
            _receivedBytes += chunk.length;
            // 更新进度
            _progressController.add(UploadProgress(
              fileName: fileName,
              received: _receivedBytes,
              total: _totalBytes,
            ));
          }

          await sink.flush();
          await sink.close();

          final fileLength = await file.length();
          setState(() {
            _serverStatus.add(
                '已接收文件: $uniqueFileName\n大小: ${_formatBytes(fileLength)}\n路径: $filePath');
          });
        }

        request.response
          ..statusCode = 200
          ..write('上传成功');
      } catch (e) {
        request.response
          ..statusCode = 500
          ..write('错误: $e');
      } finally {
        _activeRequests.remove(request); // 注销请求
        await request.response.close();
        _resetUploadState();
      }
    }
  }

  // 辅助方法：重置上传状态
  void _resetUploadState() {
    setState(() {
      _currentUploadFile = null;
      _totalBytes = 0;
      _receivedBytes = 0;
    });
  }

  // 辅助方法：格式化字节
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }
}

// 进度数据模型
class UploadProgress {
  final String fileName;
  final int received;
  final int total;

  UploadProgress({
    required this.fileName,
    required this.received,
    required this.total,
  });
}
