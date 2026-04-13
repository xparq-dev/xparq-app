// ignore_for_file: avoid_print
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() => runApp(const LogoApp());

class LogoApp extends StatefulWidget {
  const LogoApp({super.key});
  @override
  State<LogoApp> createState() => _LogoAppState();
}

class _LogoAppState extends State<LogoApp> {
  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1500));

      Future<void> saveImage(String path, bool withBackground) async {
        setState(() => _withBackground = withBackground);
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // wait for rebuild

        RenderRepaintBoundary boundary =
            _globalKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        ui.Image image = await boundary.toImage(pixelRatio: 4.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final file = File(path);
        file.writeAsBytesSync(pngBytes);
        debugPrint('SUCCESS_SAVED: $path');
      }

      try {
        // 1. Save Transparent versions
        await saveImage('assets/images/perfect_thunder_logo.png', false);
        await saveImage('assets/images/perfect_android_fg.png', false);

        // 2. Save Solid Black versions (iOS requires solid background)
        await saveImage('assets/images/perfect_ios_logo.png', true);
        await saveImage('assets/images/perfect_splash_logo.png', true);

        exit(0);
      } catch (e) {
        print(e);
        exit(1);
      }
    });
  }

  bool _withBackground = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: _globalKey,
            child: Container(
              width: 1024,
              height: 1024,
              alignment: Alignment.center,
              color: _withBackground ? Colors.black : Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Smaller Circle
                  Container(
                    width: 512,
                    height: 512,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0A1F3A),
                    ),
                  ),
                  // Sharper Bolt (no shadow)
                  const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF1D9BF0),
                    size: 400,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
