import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("test")),
    body: const Center(
      child: Text("data"),
    ),);
    throw UnimplementedError();
  }
}
