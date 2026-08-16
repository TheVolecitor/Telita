import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/settings.dart';
import '../../core/simkl_client.dart';
import 'settings_widgets.dart';

class SimklSettingsScreen extends StatefulWidget {
  const SimklSettingsScreen({super.key});

  @override
  State<SimklSettingsScreen> createState() => _SimklSettingsScreenState();
}

class _SimklSettingsScreenState extends State<SimklSettingsScreen> {
  String? _simklUserCode;
  String? _simklVerificationUrl;
  bool _isGettingDevicePin = false;
  bool _isAuthenticatingSimkl = false;

  Future<void> _startSimklDeviceFlow() async {
    final cfg = SettingsService.instance.value;
    setState(() => _isGettingDevicePin = true);
    final res = await SimklClient.requestDevicePin(customClientId: cfg.simklClientId);
    setState(() => _isGettingDevicePin = false);

    if (res['success'] == true) {
      final code = res['user_code'] as String?;
      setState(() {
        _simklUserCode = code;
        _simklVerificationUrl = res['verification_url'] as String?;
      });
      
      await Future.delayed(const Duration(seconds: 3));
      
      final uri = Uri.parse(_simklVerificationUrl ?? 'https://simkl.com/pin');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get Simkl PIN: ${res['error']}')),
        );
      }
    }
  }

  Future<void> _checkSimklDevicePin() async {
    if (_simklUserCode == null) return;
    final cfg = SettingsService.instance.value;
    setState(() => _isAuthenticatingSimkl = true);
    final res = await SimklClient.checkDevicePinStatus(
      userCode: _simklUserCode!,
      customClientId: cfg.simklClientId,
    );
    setState(() => _isAuthenticatingSimkl = false);

    if (res['success'] == true && res['authorized'] == true) {
      final token = res['access_token'] as String;
      final username = res['username'] as String;
      await SettingsService.instance.set('simklAccessToken', token);
      await SettingsService.instance.set('simklUsername', username);
      setState(() {
        _simklUserCode = null;
        _simklVerificationUrl = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to Simkl as $username!')),
        );
      }
    } else if (res['success'] == true && res['authorized'] == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still waiting for authorization on Simkl... Please approve the PIN in your browser.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking status: ${res['error']}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simkl Scrobbling'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<AppSettings>(
          valueListenable: SettingsService.instance,
          builder: (context, cfg, _) {
            return ListView(
              padding: const EdgeInsets.all(32.0),
              children: [
                buildToggle(
                  label: 'Enable Simkl Sync',
                  desc: 'Automatically scrobble watched movies & TV show episodes to your Simkl account',
                  value: cfg.simklEnabled,
                  onChanged: (val) => SettingsService.instance.set('simklEnabled', val),
                ),
                if (cfg.simklEnabled) ...[
                  if (cfg.simklUsername.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF6C63FF), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Connected as ${cfg.simklUsername}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              SettingsService.instance.set('simklAccessToken', '');
                              SettingsService.instance.set('simklUsername', '');
                            },
                            child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_simklUserCode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6C63FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Authorize Telita on Simkl',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Your Device PIN Code: ', style: TextStyle(color: Colors.white70)),
                              SelectableText(
                                _simklUserCode!,
                                style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SettingsInfoCard(
                            icon: Icons.info_outline,
                            text: '1. Click "Open simkl.com/pin"\n2. Enter code $_simklUserCode if asked\n3. Authorize Telita on the webpage\n4. Come back to this app and click "Check Connection Status"',
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onPressed: () async {
                                  final uri = Uri.parse(_simklVerificationUrl ?? 'https://simkl.com/pin');
                                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open simkl.com/pin'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.green, width: 1.5),
                                  foregroundColor: Colors.green,
                                ),
                                onPressed: _isAuthenticatingSimkl ? null : _checkSimklDevicePin,
                                child: _isAuthenticatingSimkl
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                                    : const Text('Check Connection Status'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onPressed: _isGettingDevicePin ? null : _startSimklDeviceFlow,
                          icon: _isGettingDevicePin
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync, size: 18),
                          label: const Text('Connect Simkl Account (Device PIN)'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
