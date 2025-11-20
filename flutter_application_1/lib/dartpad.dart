import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Rebuild only when necessary'),
        ),
        body: const Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              SizedBox(
                width: 300,
                child: Text('Flutter\'s algorithms for rebuilding and '
                    'repainting widgets are linear in the worst case, '
                    'and typically sub-linear. Try clicking one of '
                    'buttons below -- they\'ll tell you exactly '
                    'when they rebuild!'),
              ),
              SizedBox(height: 16),
              ClickyBuilder(),
              SizedBox(height: 16),
              ClickyBuilder(),
              SizedBox(height: 16),
              ClickyBuilder(),
            ],
          ),
        ),
      ),
    );
  }
}

class ClickyBuilder extends StatefulWidget {
  const ClickyBuilder({Key? key}) : super(key: key);

  @override
  ClickyBuilderState createState() => ClickyBuilderState();
}

class ClickyBuilderState extends State<ClickyBuilder> {
  Color color = Colors.blue;

  String pad(int i) => i.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      child: Text('Built at ${now.hour}:${pad(now.minute)}:'
          '${pad(now.second)}'),
      onPressed: () => setState(() {
        color = getRandomColor();
      }),
    );
  }
}

final rng = Random();

const randomColors = [
  Colors.blue,
  Colors.green,
  Colors.red,
  Colors.orange,
  Colors.indigo,
  Colors.deepPurple,
  Colors.white10,
];

Color getRandomColor() {
  return randomColors[rng.nextInt(randomColors.length)];
}
