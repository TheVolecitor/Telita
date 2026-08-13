import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../core/settings.dart';
import 'settings_widgets.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  Color _parseColor(String hexStr) {
    hexStr = hexStr.toUpperCase().replaceAll('#', '');
    if (hexStr.length == 6) {
      hexStr = 'FF$hexStr';
    }
    return Color(int.tryParse(hexStr, radix: 16) ?? 0xFF6C63FF);
  }

  String _toHexString(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _showColorPicker(BuildContext context, String title, Color currentColor, ValueChanged<Color> onColorChanged) {
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C2E),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: currentColor,
              onColorChanged: (c) => tempColor = c,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                onColorChanged(tempColor);
                Navigator.of(context).pop();
              },
              child: const Text('Select', style: TextStyle(color: Color(0xFF6C63FF))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
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
                buildTVDropdown<String>(
                  context: context,
                  label: 'App Theme',
                  value: cfg.appTheme,
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('Default (Dark Blue)')),
                    DropdownMenuItem(value: 'black', child: Text('Black (OLED)')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom Accent Colors')),
                  ],
                  onChanged: (val) {
                    if (val != null) SettingsService.instance.set('appTheme', val);
                  },
                ),
                if (cfg.appTheme == 'custom') ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    title: const Text('Background Color', style: TextStyle(color: Colors.white, fontSize: 15)),
                    trailing: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _parseColor(cfg.customPrimaryColor),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                    ),
                    onTap: () {
                      _showColorPicker(context, 'Pick Background Color', _parseColor(cfg.customPrimaryColor), (c) {
                        SettingsService.instance.set('customPrimaryColor', _toHexString(c));
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    title: const Text('Accent Color', style: TextStyle(color: Colors.white, fontSize: 15)),
                    trailing: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _parseColor(cfg.customSecondaryColor),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                    ),
                    onTap: () {
                      _showColorPicker(context, 'Pick Accent Color', _parseColor(cfg.customSecondaryColor), (c) {
                        SettingsService.instance.set('customSecondaryColor', _toHexString(c));
                      });
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
