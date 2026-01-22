import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:math';

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

Widget build(BuildContext context) {
  // This is used in the platform side to register the view.
  const String viewType = '<platform-view-type>';
  // Pass parameters to the platform side.
  const Map<String, dynamic> creationParams = <String, dynamic>{};

  return PlatformViewLink(
    viewType: viewType,
    surfaceFactory: (context, controller) {
      return AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      );
    },
    onCreatePlatformView: (params) {
      return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () {
            params.onFocusChanged(true);
          },
        )
        ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
        ..create();
    },
  );
}



