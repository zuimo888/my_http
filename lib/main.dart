// 添加字体依赖
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_http/pages/bottom_screen.dart';
import 'package:my_http/pages/home.dart';

void main() async {
    // 仅移动端初始化插件通信
  if (!kIsWeb && !Platform.isWindows) {
    FlutterForegroundTask.initCommunicationPort();
  }

  WidgetsFlutterBinding.ensureInitialized();
  await GoogleFonts.pendingFonts([GoogleFonts.robotoMono()]);
 
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), // 主色
          background: const Color(0xFFECEFF1), // 背景
        ),
        textTheme: GoogleFonts.robotoTextTheme(
          TextTheme(
            headlineSmall: TextStyle( // 原headline4
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A237E),
            ),
            titleMedium: TextStyle( // 原subtitle1
              fontSize: 16,
              fontFamily: 'RobotoMono',
              color: Colors.white,
            ),
            labelLarge: TextStyle( // 按钮文字
              fontSize: 15,
              letterSpacing: 1.2,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
            textStyle: GoogleFonts.roboto(
              fontSize: 15,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500
            )
          )
        ) 
      ),
      home: BottomScreen(),
    );
  }
}