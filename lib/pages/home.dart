import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:synchronized/extension.dart';
import 'package:path/path.dart' as path;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _processedIps = 0;// 普通计数器
  final _lock = Object();// 锁对象
  CancelToken _cancelToken = CancelToken();// 使用 dio 的取消令牌
  TextEditingController ipController = TextEditingController();
  late FToast fToast;
   // 局域网设备 ip 列表  
  List<String> devices = [
    '192.168.x.x(示例)',
  ];
   // 是否开始扫描
  bool isScanning = false;
  double _scanProgress = 0.0; // 进度值（0.0 ~ 1.0）
   // 扫描是否取消
  bool _cancelScan = false;
  static const int _batchSize = 20;
  static const int _timeoutSeconds = 2;
    // 本机 ip
  var ip;
    // 已选择文件路径
  String? filePath;
    // 已选择文件
  var _pickFile;
   // 发送文件目标 ip
  var sIp;

  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(context);
    checkPermission();
  }

  void checkPermission() async {
    if (Platform.isAndroid) {
      try {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.locationWhenInUse,
          Permission.storage
        ].request();

        PermissionStatus locationPermission = statuses[Permission.locationWhenInUse]!;
        PermissionStatus storagePermission = statuses[Permission.storage]!;

        if (locationPermission.isDenied) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('需要定位权限'),
              content: const Text('获取 WiFi 信息需要位置权限'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('去设置'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    checkPermission(); // 重试权限请求
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        } else if (locationPermission.isGranted) {
          getMyIp();
        }

        if (storagePermission.isDenied) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('需要存储权限'),
              content: const Text('选择文件需要存储权限!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('去设置'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    checkPermission(); // 重试权限请求
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (locationPermission.isGranted && storagePermission.isGranted) {
          _WifiListener();
        }
      } catch (e) {
        if (e is PlatformException && e.code == 'PermissionRequestCancelledException') {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('权限请求取消'),
              content: const Text('权限请求被取消，部分功能可能无法正常使用，是否重新请求权限？'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    checkPermission(); // 重新请求权限
                  },
                  child: const Text('重新请求'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('取消'),
                ),
              ],
            ),
          );
        }
      }
    }else{
      _WifiListener();
    }
  }
  //监听wifi
  void _WifiListener() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      setState(() {
        getMyIp();
      });
    } else {
      fToast.showToast(
        child: const Text('请连接 wifi！'),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('快传'),
      ),
      body: Column(
        children: [
          Text(
            "本机 ip:$ip",
            style: const TextStyle(
              color: Color(0xFF2A4F8C),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: isScanning
                ? LinearProgressIndicator(
                    value: _scanProgress,
                    minHeight: 15,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF26A69A)),
                  )
                : Text(
                    '扫描完成，共发现 ${devices.length} 台设备',
                    style: const TextStyle(color: Colors.green, fontSize: 16),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  child: isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.radar,
                          size: 20,
                        ),
                ),
                label: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    isScanning ? "扫描中..." : "扫描设备",
                    style: const TextStyle(
                      fontSize: 15,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isScanning
                      ? Colors.blueGrey[700]
                      : const Color.fromARGB(255, 92, 177, 246),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  elevation: isScanning ? 0 : 2,
                  shadowColor: Colors.black.withOpacity(0.2),
                ),
                onPressed: isScanning ? null : scanDevices,
              ),
              Visibility(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1A237E)),
                  ),
                  onPressed: cancelScan,
                  child: const Text("取消扫描"),
                ),
                visible: _cancelScan,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: const Text("选择文件"),
                onPressed: pickFile,
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: filePath != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF26A69A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              filePath!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Color(0xFF26A69A),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '未选择文件',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("发送文件"),
            onPressed: () {
              if (filePath == null) {
                fToast.showToast(
                  child: const Text('请选择文件！'),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 2),
                );
              } else {
                if (sIp == null && ipController.text.isEmpty) {
                  fToast.showToast(
                    child: const Text('请选择目标 ip！'),
                    gravity: ToastGravity.BOTTOM,
                    toastDuration: const Duration(seconds: 2),
                  );
                } else {
                  sIp = ipController.text;
                  sendFile(sIp);
                }
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            child: TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: '请输入目标 ip',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      sIp = devices[index];
                    },
                    splashColor: const Color(0xFF1A237E).withOpacity(0.2),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF4A56C6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueGrey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '设备 IP: ${devices[index]}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
 //取消扫描
  void cancelScan() {
    _cancelToken.cancel();
    setState(() {
      _scanProgress = 0.0;
      isScanning = false;
      _cancelScan = false;
    });
  }
  //扫描设备ip
  void scanDevices() async {
    setState(() {
      devices.clear();
      isScanning = true;
      _scanProgress = 0.0;
      _processedIps = 0;
      _cancelScan = true;
      _cancelToken = CancelToken();
    });

    final totalIps = 254;
    final ipPrefix = truncateIP(ip);

    try {
      for (int batch = 0; batch < (totalIps / _batchSize).ceil(); batch++) {
        if (_cancelToken.isCancelled) break;

        final start = batch * _batchSize + 1;
        final end = (batch + 1) * _batchSize;
        final currentBatchSize =
            end > totalIps ? totalIps - start + 1 : _batchSize;

        final requests = List.generate(currentBatchSize, (i) => start + i)
            .map((i) => _scanIP('$ipPrefix.$i'))
            .toList();

        await Future.any([
          Future.wait(requests),
          _cancelToken.whenCancel.then((_) => Future.value()),
        ]);
      }
    } finally {
      setState(() => isScanning = false);
    }
  }
   //扫描设备ip
  Future<void> _scanIP(String targetip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$targetip:8080/ping'))
          .timeout(
            const Duration(seconds: _timeoutSeconds),
            onTimeout: () => http.Response('Timeout', 408),
          )
          .catchError((e) {
        print('Error: $e');
        if (e is SocketException) {
          print('SocketException: ${e.message}');
        }
        if (e is TimeoutException) {
          print('TimeoutException: ${e.message}');
        }
        if (e is Exception) {
          print('Exception: ${e.toString()}');
        }
        if (e is Error) {
          print('Error: ${e.stackTrace}');
        }
        return http.Response('Error', 500);
      });

      if (response.statusCode == 200) {
        setState(() => devices.add(targetip));
      }
    } finally {
      await _lock.synchronized(() async {
        _processedIps++;
        _updateProgress();
      });
    }
  }

  void _updateProgress() {
    final newProgress = _processedIps / 255;
    if ((newProgress - _scanProgress).abs() > 0.01 || newProgress == 1) {
      setState(() => _scanProgress = newProgress.clamp(0.0, 1.0));
    }
  }

  void getMyIp() async {
    try {
      final newIp = await NetworkInfo().getWifiIP();
      setState(() {
        ip = newIp ?? '0.0.0.0';
      });
    } catch (e) {
      setState(() {
        ip = '获取失败: $e';
      });
    }
  }
  //选择文件
  void pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        _pickFile = File(result.files.single.path!);
        setState(() {
          filePath = result.files.single.path!;
        });
      }
    } catch (e) {
      fToast.showToast(
        child: Text(e.toString()),
        gravity: ToastGravity.CENTER,
        toastDuration: const Duration(seconds: 2),
      );
    }
  }
  //发送文件
  void sendFile(String ip) async {
    try {
      var result =
          http.MultipartRequest('POST', Uri.parse('http://$ip:8080/upload'));
      result.files.add(await http.MultipartFile.fromPath('file', _pickFile.path,
          filename: path.basename(_pickFile.path)));
          print(path.basename(_pickFile.path));
      var request = await result.send();
      if (request.statusCode == 200) {
        fToast.showToast(
          child: const Text('文件发送成功！'),
          gravity: ToastGravity.CENTER,
          toastDuration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      fToast.showToast(
        child: Text('文件发送失败:${e.toString()}'),
        gravity: ToastGravity.CENTER,
        toastDuration: const Duration(seconds: 2),
      );
    }
  }

  String truncateIP(String ip) {
    List<String> parts = ip.split('.');
    if (parts.length >= 4) {
      return parts.sublist(0, 3).join('.');
    }
    return ip;
  }
}