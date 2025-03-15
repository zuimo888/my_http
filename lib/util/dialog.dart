//2. 在合适的地方调用_showToast()方法
import 'package:flutter/material.dart';

Widget SuccessToast(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: Colors.greenAccent,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check),
        SizedBox(
          width: 12.0,
        ),
        Text(text),
      ],
    ),
  );
}
Widget FailedToast(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: const Color.fromARGB(255, 54, 152, 244),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error),
        SizedBox(
          width: 8.0,
        ),
        Text(text,style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
      ],
    ),
  );
}