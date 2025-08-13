import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codecraft_project/Screens/Menu/intro_screen.dart';
import 'package:codecraft_project/Screens/wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _opacity = 1.0;
  late Timer _fadeTimer;

  @override
  void initState() {
    super.initState();

    _fadeTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      setState(() {
        _opacity = _opacity == 1.0 ? 0.2 : 1.0;
      });
    });

    Timer(const Duration(seconds: 3), () async {
      _fadeTimer.cancel();
      final prefs = await SharedPreferences.getInstance();
      final hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;
      if (!hasSeenIntro) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const IntroScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Wrapper()),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 2000),
              opacity: _opacity,
              child: Image.asset(
                'assets/logo.png', 
                width: 400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
