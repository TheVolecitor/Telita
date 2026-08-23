import 'package:flutter/material.dart';
import '../../core/settings.dart';
import 'settings_widgets.dart';

class IntroSkipSettingsScreen extends StatelessWidget {
  const IntroSkipSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intro Skip'),
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
                buildToggle(
                  label: 'Enable Intro Skip',
                  desc: 'Automatically fetch timestamps to skip intros and recaps',
                  value: cfg.introSkipEnabled,
                  onChanged: (val) => SettingsService.instance.set('introSkipEnabled', val),
                ),
                buildTVDropdown<String>(
                  context: context,
                  label: 'Intro Skip Provider',
                  desc: 'Service used to fetch skip timestamps',
                  value: cfg.introSkipProvider,
                  items: const [
                    DropdownMenuItem(value: 'introdb.app', child: Text('IntroDB.app')),
                    DropdownMenuItem(value: 'theintrodb.org', child: Text('TheIntroDB.org')),
                  ],
                  onChanged: (val) {
                    if (val != null) SettingsService.instance.set('introSkipProvider', val);
                  },
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
