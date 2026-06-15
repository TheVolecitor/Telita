import 'package:flutter/material.dart';
import '../main.dart'; // To navigate to AppContainer
import '../core/auth.dart';
import 'spinning_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}



class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkReady();
    AuthService.instance.addListener(_checkReady);
  }

  void _checkReady() {
    if (AuthService.instance.value.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateToHome();
      });
    }
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_checkReady);
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AppContainer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Forced OLED black
      body: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: const BrandLoadingIndicator(color: Colors.white, size: 300),
        ),
      ),
    );
  }
}

