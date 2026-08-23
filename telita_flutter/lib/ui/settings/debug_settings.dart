import 'package:flutter/material.dart';
import '../../core/settings.dart';
import 'settings_widgets.dart';

class DebugSettingsScreen extends StatefulWidget {
  const DebugSettingsScreen({super.key});

  @override
  State<DebugSettingsScreen> createState() => _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends State<DebugSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: SettingsService.instance,
      builder: (context, settings, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Debug Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text(
                'Use these toggles to identify what is causing playback delays. Disable one at a time to narrow down the issue.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              buildToggle(
                label: 'Disable Skip Segments Fetching',
                desc: 'Prevents the app from querying the intro skip API before playback.',
                value: settings.debugDisableSkipSegments,
                onChanged: (val) {
                  SettingsService.instance.set('debugDisableSkipSegments', val);
                },
              ),
              const SizedBox(height: 16),
              buildToggle(
                label: 'Disable Watch History Save',
                desc: 'Prevents the app from saving watch progress to the local database.',
                value: settings.debugDisableWatchHistory,
                onChanged: (val) {
                  SettingsService.instance.set('debugDisableWatchHistory', val);
                },
              ),
              const SizedBox(height: 16),
              buildToggle(
                label: 'Disable Simkl Sync',
                desc: 'Prevents the app from scrobbling progress to Simkl API.',
                value: settings.debugDisableSimkl,
                onChanged: (val) {
                  SettingsService.instance.set('debugDisableSimkl', val);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
