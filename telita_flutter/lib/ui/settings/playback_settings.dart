import 'package:flutter/material.dart';
import '../../core/settings.dart';
import 'settings_widgets.dart';

class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playback'),
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
              children: animateStaggeredList([
                buildTVDropdown<String>(
                  context: context,
                  label: 'Hardware Decoding',
                  desc: 'Use GPU for video decoding',
                  value: cfg.hardwareDecoding,
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto (Recommended)')),
                    DropdownMenuItem(value: 'd3d11va', child: Text('Direct3D 11 (Zero-Copy)')),
                    DropdownMenuItem(value: 'd3d11va-copy', child: Text('Direct3D 11 (Copy-Back)')),
                    DropdownMenuItem(value: 'dxva2', child: Text('DXVA2 (Zero-Copy)')),
                    DropdownMenuItem(value: 'dxva2-copy', child: Text('DXVA2 (Copy-Back)')),
                    DropdownMenuItem(value: 'no', child: Text('Disabled (CPU)')),
                  ],
                  onChanged: (val) {
                    if (val != null) SettingsService.instance.set('hardwareDecoding', val);
                  },
                ),
                buildSlider(
                  label: 'Default Volume',
                  value: cfg.defaultVolume.toDouble(),
                  min: 0,
                  max: 100,
                  unit: '%',
                  onChanged: (val) => SettingsService.instance.set('defaultVolume', val.round()),
                ),
                buildToggle(
                  label: 'Remember Volume',
                  desc: 'Save volume level between sessions',
                  value: cfg.rememberVolume,
                  onChanged: (val) => SettingsService.instance.set('rememberVolume', val),
                ),
                buildToggle(
                  label: 'Auto-Resume',
                  desc: 'Automatically resume from last position without asking',
                  value: !cfg.resumePrompt,
                  onChanged: (val) => SettingsService.instance.set('resumePrompt', !val),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
