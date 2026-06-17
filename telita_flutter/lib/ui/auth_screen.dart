import 'package:flutter/material.dart';
import '../core/auth.dart';

import 'dart:async';
import 'dart:io';
import 'package:qr_flutter/qr_flutter.dart';
import 'spinning_logo.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onDone;
  final bool canClose;
  final VoidCallback? onClose;

  const AuthScreen({
    super.key,
    required this.onDone,
    this.canClose = false,
    this.onClose,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = true;
  String _error = '';
  
  String? _deviceCode;
  String? _userCode;
  String? _verificationUri;
  Timer? _pollingTimer;

  bool _isDisposed = false;

  // Windows form state
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux) {
      _isLoading = false;
    } else {
      _initDeviceAuth();
    }
  }

  Future<void> _initDeviceAuth() async {
    if (_isDisposed) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final res = await AuthService.instance.getDeviceCode();
    if (_isDisposed) return;
    
    if (res.containsKey('error')) {
      setState(() {
        _error = res['error'];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _deviceCode = res['device_code'];
      _userCode = res['user_code'];
      _verificationUri = res['verification_uri'];
      _isLoading = false;
    });

    _pollingTimer?.cancel();
    _pollingTimer = Timer(const Duration(seconds: 5), _startPolling);
  }

  void _startPolling() async {
    if (_isDisposed || _deviceCode == null) return;
    
    final res = await AuthService.instance.pollDeviceToken(_deviceCode!);
    if (_isDisposed) return;

    if (res['success'] == true) {
      if (mounted) widget.onDone();
    } else if (res['error'] == 'expired_token' || res['error'] == 'invalid_grant') {
      _initDeviceAuth(); // restart flow
    } else {
      _pollingTimer = Timer(const Duration(seconds: 5), _startPolling);
    }
  }

  Future<void> _handleWindowsSubmit() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    
    Map<String, dynamic> res;
    if (_isLogin) {
      res = await AuthService.instance.login(email, password);
    } else {
      res = await AuthService.instance.register(email, password, name: name.isNotEmpty ? name : null);
    }
    
    if (_isDisposed) return;
    
    if (res.containsKey('error')) {
      setState(() {
        _error = res['error'];
        _isLoading = false;
      });
    } else {
      if (mounted) widget.onDone();
    }
  }

  void _handleGuest() async {
    _pollingTimer?.cancel();
    await AuthService.instance.continueAsGuest();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Material(
        color: Colors.black87,
        child: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C2E),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: widget.canClose ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                children: [
                  if (widget.canClose)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: widget.onClose,
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLogin ? 'Sign in to Telita' : 'Create an Account',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  if (widget.canClose) const SizedBox(width: 48), // Balance centering
                ],
              ),
              const SizedBox(height: 40),

              if (_isLoading)
                const BrandLoadingIndicator(size: 60)
              else if (_error.isNotEmpty && !(Platform.isWindows || Platform.isLinux))
                Column(
                  children: [
                    Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initDeviceAuth,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else if (Platform.isWindows || Platform.isLinux)
                _buildWindowsForm()
              else
                _buildQRForm(),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  autofocus: !(Platform.isWindows || Platform.isLinux),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _handleGuest,
                  child: const Text('Continue as Guest', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildWindowsForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
          ),
        if (!_isLogin)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        TextField(
          controller: _emailController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Email',
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _handleWindowsSubmit(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _handleWindowsSubmit,
            child: Text(_isLogin ? 'Login' : 'Sign Up', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _isLogin = !_isLogin;
              _error = '';
            });
          },
          child: Text(_isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login'),
        ),
      ],
    );
  }

  Widget _buildQRForm() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: _verificationUri ?? '',
            version: QrVersions.auto,
            size: 160.0,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Scan QR code or visit',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _verificationUri ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text(
                '2. Enter code',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _userCode ?? '',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

