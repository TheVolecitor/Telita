import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/settings.dart';
import '../core/auth.dart';

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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _obscureApiKey = true;
  bool _showRatingToggles = false;

  @override
  void initState() {
    super.initState();
    SettingsService.instance.init();
    AuthService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<AppSettings>(
          valueListenable: SettingsService.instance,
          builder: (context, cfg, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),

                  // --- APPEARANCE ---
                  _buildSectionHeader(Icons.palette_outlined, 'Appearance'),
                  _buildTVDropdown<String>(
                    label: 'App Theme',
                    value: cfg.appTheme,
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text('Default (Dark Blue)')),
                      DropdownMenuItem(value: 'black', child: Text('Black (OLED)')),
                    ],
                    onChanged: (val) {
                      if (val != null) SettingsService.instance.set('appTheme', val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- SUBTITLES ---
                  _buildSectionHeader(Icons.subtitles_outlined, 'Subtitles'),
                  _buildToggle(
                    label: 'Enable Subtitles',
                    desc: 'Auto-load subtitles when available',
                    value: cfg.subtitleEnabled,
                    onChanged: (val) => SettingsService.instance.set('subtitleEnabled', val),
                  ),
                  _buildTVDropdown<String>(
                    label: 'Default Language',
                    value: cfg.subtitleLanguage,
                    items: subtitleLangs
                        .map((l) => DropdownMenuItem(value: l['code']!, child: Text(l['label']!)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) SettingsService.instance.set('subtitleLanguage', val);
                    },
                  ),
                  _buildSlider(
                    label: 'Font Size',
                    desc: 'Default size in pixels',
                    value: cfg.subtitleFontSize.toDouble(),
                    min: 20,
                    max: 80,
                    unit: 'px',
                    onChanged: (val) => SettingsService.instance.set('subtitleFontSize', val.round()),
                  ),
                  _buildSlider(
                    label: 'Vertical Position',
                    desc: 'Distance from top of screen',
                    value: cfg.subtitlePosition.toDouble(),
                    min: 0,
                    max: 100,
                    unit: '%',
                    onChanged: (val) => SettingsService.instance.set('subtitlePosition', val.round()),
                  ),
                  _buildTVDropdown<String>(
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
                  _buildSlider(
                    label: 'Background Opacity',
                    desc: 'Opacity of the subtitle background box',
                    value: cfg.subtitleBgOpacity.toDouble(),
                    min: 0,
                    max: 100,
                    unit: '%',
                    onChanged: (val) => SettingsService.instance.set('subtitleBgOpacity', val.round()),
                  ),

                  const SizedBox(height: 24),

                  // --- PLAYBACK ---
                  _buildSectionHeader(Icons.play_circle_outline, 'Playback'),
                  _buildTVDropdown<String>(
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
                  _buildSlider(
                    label: 'Default Volume',
                    value: cfg.defaultVolume.toDouble(),
                    min: 0,
                    max: 100,
                    unit: '%',
                    onChanged: (val) => SettingsService.instance.set('defaultVolume', val.round()),
                  ),
                  _buildToggle(
                    label: 'Remember Volume',
                    desc: 'Save volume level between sessions',
                    value: cfg.rememberVolume,
                    onChanged: (val) => SettingsService.instance.set('rememberVolume', val),
                  ),
                  _buildToggle(
                    label: 'Auto-Resume',
                    desc: 'Automatically resume from last position without asking',
                    value: !cfg.resumePrompt,
                    onChanged: (val) => SettingsService.instance.set('resumePrompt', !val),
                  ),

                  const SizedBox(height: 24),
                  _buildToggle(
                    label: 'Enable Intro Skip',
                    desc: 'Automatically fetch timestamps to skip intros and recaps',
                    value: cfg.introSkipEnabled,
                    onChanged: (val) => SettingsService.instance.set('introSkipEnabled', val),
                  ),
                  _buildTVDropdown<String>(
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
                  const SizedBox(height: 24),
                  // --- MDBLIST RATINGS ---
                  _buildSectionHeader(Icons.star_outline, 'MDBList Ratings'),
                  _buildToggle(
                    label: 'Enable MDBList Ratings',
                    desc: 'Fetch and display IMDb, Rotten Tomatoes, Metacritic & Trakt ratings',
                    value: cfg.mdbListEnabled,
                    onChanged: (val) => SettingsService.instance.set('mdbListEnabled', val),
                  ),
                  if (cfg.mdbListEnabled) ...[
                    _buildTextField(
                      label: 'MDBList API Key',
                      desc: 'Get your key at mdblist.com/preferences',
                      value: cfg.mdbListApiKey,
                      onChanged: (val) => SettingsService.instance.set('mdbListApiKey', val.trim()),
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
                            _buildToggle(
                              label: 'Show Overall MDBList Score',
                              value: cfg.mdbListShowScore,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowScore', val),
                            ),
                            _buildToggle(
                              label: 'Show IMDb Rating',
                              value: cfg.mdbListShowImdb,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowImdb', val),
                            ),
                            _buildToggle(
                              label: 'Show Rotten Tomatoes Score',
                              value: cfg.mdbListShowTomatoes,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowTomatoes', val),
                            ),
                            _buildToggle(
                              label: 'Show Metacritic Score',
                              value: cfg.mdbListShowMetacritic,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowMetacritic', val),
                            ),
                            _buildToggle(
                              label: 'Show Letterboxd Score',
                              value: cfg.mdbListShowLetterboxd,
                              onChanged: (val) => SettingsService.instance.set('mdbListShowLetterboxd', val),
                            ),
                            _buildToggle(
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

                const SizedBox(height: 24),

                  // --- ACCOUNT ---
                  _buildSectionHeader(Icons.person_outline, 'Account'),
                  ValueListenableBuilder<AuthState>(
                    valueListenable: AuthService.instance,
                    builder: (context, authState, _) {
                      final title = authState.isGuest ? 'Guest Mode' : (authState.user?.email ?? 'Signed In');
                      final desc = authState.isGuest ? 'Not syncing to cloud' : 'Profile: ${authState.profile?.name ?? 'None'}';

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(desc, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: authState.isGuest ? const Color(0xFF6C63FF) : Colors.redAccent.withOpacity(0.2),
                                foregroundColor: authState.isGuest ? Colors.white : Colors.redAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                await AuthService.instance.logout();
                              },
                              child: Text(authState.isGuest ? 'Sign In' : 'Sign Out'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    String? desc,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                if (desc != null) ...[
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF6C63FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    String? desc,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  if (desc != null) ...[
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                  ],
                ],
              ),
              Text('${value.round()}$unit', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          _TVSlider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTVDropdown<T>({
    required String label,
    String? desc,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final selectedWidget = items.firstWhere((e) => e.value == value, orElse: () => items.first).child;
    final String selectedText = selectedWidget is Text ? (selectedWidget.data ?? '') : '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                if (desc != null) ...[
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF1C1C2E),
                      title: Text(label, style: const TextStyle(color: Colors.white)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: items.map((item) {
                            final isSelected = item.value == value;
                            return ListTile(
                              autofocus: isSelected,
                              focusColor: Colors.white10,
                              title: DefaultTextStyle(
                                style: TextStyle(color: isSelected ? Colors.white70 : Colors.white),
                                child: item.child,
                              ),
                              selected: isSelected,
                              onTap: () {
                                onChanged(item.value);
                                Navigator.of(context).pop();
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(selectedText, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? desc,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final controller = TextEditingController(text: value);
    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          if (desc != null) ...[
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.white30, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: _obscureApiKey,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter MDBList API Key',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6C63FF)),
              ),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TVSlider extends StatefulWidget {
  final double value, min, max;
  final ValueChanged<double> onChanged;

  const _TVSlider({required this.value, required this.min, required this.max, required this.onChanged});

  @override
  State<_TVSlider> createState() => _TVSliderState();
}

class _TVSliderState extends State<_TVSlider> {
  late final FocusNode _node = FocusNode(onKeyEvent: _handleKey);

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        node.focusInDirection(TraversalDirection.up);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        node.focusInDirection(TraversalDirection.down);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      focusNode: _node,
      value: widget.value,
      min: widget.min,
      max: widget.max,
      activeColor: const Color(0xFF6C63FF),
      inactiveColor: Colors.white10,
      onChanged: widget.onChanged,
    );
  }
}
