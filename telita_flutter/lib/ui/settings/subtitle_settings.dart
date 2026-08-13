import 'package:flutter/material.dart';
import '../../core/settings.dart';
import 'settings_widgets.dart';

const List<Map<String, String>> subtitleLangs = [
  {'code': 'off', 'label': 'Off'},
  {'code': 'eng', 'label': 'English'},
  {'code': 'hin', 'label': 'Hindi'},
  {'code': 'tam', 'label': 'Tamil'},
  {'code': 'tel', 'label': 'Telugu'},
  {'code': 'mal', 'label': 'Malayalam'},
  {'code': 'kan', 'label': 'Kannada'},
  {'code': 'ben', 'label': 'Bengali'},
  {'code': 'mar', 'label': 'Marathi'},
  {'code': 'fra', 'label': 'French'},
  {'code': 'spa', 'label': 'Spanish'},
  {'code': 'deu', 'label': 'German'},
  {'code': 'jpn', 'label': 'Japanese'},
  {'code': 'kor', 'label': 'Korean'},
  {'code': 'zho', 'label': 'Chinese'},
];

class SubtitleSettingsScreen extends StatelessWidget {
  const SubtitleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subtitles'),
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
                  label: 'Enable Subtitles',
                  desc: 'Auto-load subtitles when available',
                  value: cfg.subtitleEnabled,
                  onChanged: (val) => SettingsService.instance.set('subtitleEnabled', val),
                ),
                buildTVDropdown<String>(
                  context: context,
                  label: 'Default Language',
                  value: cfg.subtitleLanguage,
                  items: subtitleLangs
                      .map((l) => DropdownMenuItem(value: l['code']!, child: Text(l['label']!)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) SettingsService.instance.set('subtitleLanguage', val);
                  },
                ),
                buildSlider(
                  label: 'Font Size',
                  desc: 'Default size in pixels',
                  value: cfg.subtitleFontSize.toDouble(),
                  min: 20,
                  max: 80,
                  unit: 'px',
                  onChanged: (val) => SettingsService.instance.set('subtitleFontSize', val.round()),
                ),
                buildSlider(
                  label: 'Vertical Position',
                  desc: 'Distance from top of screen',
                  value: cfg.subtitlePosition.toDouble(),
                  min: 0,
                  max: 100,
                  unit: '%',
                  onChanged: (val) => SettingsService.instance.set('subtitlePosition', val.round()),
                ),
                buildTVDropdown<String>(
                  context: context,
                  label: 'Style',
                  value: cfg.subtitleStyle,
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('Default')),
                    DropdownMenuItem(value: 'shadow', child: Text('Drop Shadow')),
                    DropdownMenuItem(value: 'outline', child: Text('Outline')),
                    DropdownMenuItem(value: 'opaque-bg', child: Text('Opaque Background')),
                  ],
                  onChanged: (val) {
                    if (val != null) SettingsService.instance.set('subtitleStyle', val);
                  },
                ),
                buildSlider(
                  label: 'Background Opacity',
                  desc: 'Opacity of the subtitle background box',
                  value: cfg.subtitleBgOpacity.toDouble(),
                  min: 0,
                  max: 100,
                  unit: '%',
                  onChanged: (val) => SettingsService.instance.set('subtitleBgOpacity', val.round()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
