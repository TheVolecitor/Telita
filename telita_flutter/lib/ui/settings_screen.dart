import 'package:flutter/material.dart';
import '../core/settings.dart';
import '../core/auth.dart';
import 'settings/appearance_settings.dart';
import 'settings/subtitle_settings.dart';
import 'settings/playback_settings.dart';
import 'settings/intro_skip_settings.dart';
import 'settings/mdblist_settings.dart';
import 'settings/simkl_settings.dart';
import 'settings/account_settings.dart';
import 'settings/catalog_settings.dart';
import 'settings/settings_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    SettingsService.instance.init();
    AuthService.instance.init();
  }

  void _navigateTo(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(32.0),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 32.0),
              child: Text(
                'Settings',
                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
            ),
            
            _buildCategoryTile(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: 'App Theme, custom accent and background colors',
              onTap: () => _navigateTo(const AppearanceSettingsScreen()),
            ),
            _buildCategoryTile(
              icon: Icons.subtitles_outlined,
              title: 'Subtitles',
              subtitle: 'Language preferences, size, position, and visual styling',
              onTap: () => _navigateTo(const SubtitleSettingsScreen()),
            ),
            _buildCategoryTile(
              icon: Icons.view_carousel_outlined,
              title: 'Discover Page',
              subtitle: 'Rearrange catalogs, restrict limits, and toggle visibility on Discover screen',
              onTap: () => _navigateTo(const CatalogSettingsScreen()),
            ),
            _buildCategoryTile(
              icon: Icons.play_circle_outline,
              title: 'Playback',
              subtitle: 'Hardware decoding, default volume levels, and resume behavior',
              onTap: () => _navigateTo(const PlaybackSettingsScreen()),
            ),
            _buildCategoryTile(
              icon: Icons.fast_forward_outlined,
              title: 'Intro Skip',
              subtitle: 'Automated skipping of intros, credits, and recap segments',
              onTap: () => _navigateTo(const IntroSkipSettingsScreen()),
            ),
            _buildCategoryTile(
              icon: Icons.star_outline,
              title: 'MDBList Ratings',
              subtitle: 'Configure IMDb, Rotten Tomatoes, Metacritic, & Trakt scores',
              onTap: () => _navigateTo(const MDBListSettingsScreen()),
            ),
            _buildCategoryTile(
              icon: Icons.sync_outlined,
              title: 'Simkl Scrobbling',
              subtitle: 'Automatic tracking and scrobbling of watched movies & TV shows',
              onTap: () => _navigateTo(const SimklSettingsScreen()),
            ),
            _buildCategoryTile(
              icon: Icons.person_outline,
              title: 'Account',
              subtitle: 'Sign in, Sign out, manage profiles and cloud synchronization',
              onTap: () => _navigateTo(const AccountSettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 28),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white30, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
