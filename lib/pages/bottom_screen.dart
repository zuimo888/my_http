import 'package:flutter/material.dart';
import 'package:my_http/pages/accept_screen.dart';
import 'package:my_http/pages/home.dart';

class BottomScreen extends StatefulWidget {
  const BottomScreen({super.key});

  @override
  State<BottomScreen> createState() => _BottomScreenState();
}

class _BottomScreenState extends State<BottomScreen> {
  //页面集合
  final List<Widget> pages = [HomePage(), AcceptScreen()];
  //当前页面索引
  int currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //保留页面防止页面重构
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        height: 75, // 增加高度以容纳圆角
        // margin: EdgeInsets.symmetric(horizontal: 16), // 外边距留出圆角空间
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(10), // 顶部圆角
            // bottom: Radius.circular(20), // 若需要底部也圆角
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => setState(() => currentIndex = index),
            items: [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '发送端'),
              BottomNavigationBarItem(icon: Icon(Icons.add), label: '接受端'),
            ],
            backgroundColor: Colors.white, // 必须设置背景色以覆盖阴影
          ),
        ),
      ),
    );
  }

}
