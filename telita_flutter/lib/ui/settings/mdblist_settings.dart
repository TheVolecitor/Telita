import 'package:flutter/material.dart';
import '../../core/settings.dart';
import 'settings_widgets.dart';

class MDBListSettingsScreen extends StatefulWidget {
  const MDBListSettingsScreen({super.key});

  @override
  State<MDBListSettingsScreen> createState() => _MDBListSettingsScreenState();
}

class _MDBListSettingsScreenState extends State<MDBListSettingsScreen> {
  bool _showRatingToggles = false;
  bool _obscureApiKey = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MDBList Ratings'),
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
                  label: 'Enable MDBList Ratings',
                  desc: 'Fetch and display IMDb, Rotten Tomatoes, Metacritic & Trakt ratings',
                  value: cfg.mdbListEnabled,
                  onChanged: (val) => SettingsService.instance.set('mdbListEnabled', val),
                ),
                if (cfg.mdbListEnabled) ...[
                  const SizedBox(height: 12),
                  const SettingsInfoCard(
                    icon: Icons.info_outline,
                    text: 'Get your MDBList API key at mdblist.com/preferences',
                    color: Colors.blueAccent,
                  ),
                  buildTextField(
                    label: 'MDBList API Key',
                    value: cfg.mdbListApiKey,
                    onChanged: (val) => SettingsService.instance.set('mdbListApiKey', val.trim()),
                    obscureText: _obscureApiKey,
                    onToggleObscure: () => setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                  if (cfg.mdbListApiKey.isNotEmpty) ...[
                    InkWell(
                      onTap: () => setState(() => _showRatingToggles = !_showRatingToggles),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tune, color: Color(0xFF6C63FF), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Customize Rating Displays',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Icon(
                              _showRatingToggles ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showRatingToggles) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          children: [
                            buildToggle(
                              label: 'Show Overall MDBList Score',
                              value: cfg.mdbListShowScore,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowScore', val),
                            ),
                            buildToggle(
                              label: 'Show IMDb Rating',
                              value: cfg.mdbListShowImdb,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowImdb', val),
                            ),
                            buildToggle(
                              label: 'Show Rotten Tomatoes Score',
                              value: cfg.mdbListShowTomatoes,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowTomatoes', val),
                            ),
                            buildToggle(
                              label: 'Show Metacritic Score',
                              value: cfg.mdbListShowMetacritic,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowMetacritic', val),
                            ),
                            buildToggle(
                              label: 'Show Letterboxd Score',
                              value: cfg.mdbListShowLetterboxd,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowLetterboxd', val),
                            ),
                            buildToggle(
                              label: 'Show Trakt Score',
                              value: cfg.mdbListShowTrakt,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowTrakt', val),
                            ),
                          ],
                        ),
                      ),
                    ],
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
