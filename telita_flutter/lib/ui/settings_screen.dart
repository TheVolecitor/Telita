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
import 'settings/download_settings.dart';
import 'settings/settings_widgets.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
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
            
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 400),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: widget,
                      ),
                    ),
                    children: [
                      _buildCategoryTile(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        subtitle: 'App Theme, custom accent and background colors',
                        onTap: () => _navigateTo(const AppearanceSettingsScreen()),
                      ),
                      Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
                      _buildCategoryTile(
                        icon: Icons.subtitles_outlined,
                        title: 'Subtitles',
                        subtitle: 'Language preferences, size, position, and visual styling',
                        onTap: () => _navigateTo(const SubtitleSettingsScreen()),
                      ),
                      Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
                      _buildCategoryTile(
                        icon: Icons.view_carousel_outlined,
                        title: 'Discover Page',
                        subtitle: 'Rearrange catalogs, restrict limits, and toggle visibility on Discover screen',
                        onTap: () => _navigateTo(const CatalogSettingsScreen()),
                      ),
                      Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
                      _buildCategoryTile(
                        icon: Icons.play_circle_outline,
                        title: 'Playback',
                        subtitle: 'Hardware decoding, default volume levels, and resume behavior',
                        onTap: () => _navigateTo(const PlaybackSettingsScreen()),
                      ),
                      Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
                      _buildCategoryTile(
                        icon: Icons.download_for_offline_outlined,
                        title: 'Downloads',
                        subtitle: 'Offline library storage path and settings',
                        onTap: () => _navigateTo(const DownloadSettingsScreen()),
                      ),
                      Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
                      _buildCategoryTile(
                        icon: Icons.fast_forward_outlined,
                        title: 'Intro Skip',
                        subtitle: 'Automated skipping of intros, credits, and recap segments',
                        onTap: () => _navigateTo(const IntroSkipSettingsScreen()),
                      ),
                      Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
                      _buildCategoryTile(
                        icon: Icons.star_outline,
                        title: 'MDBList Ratings',
                        subtitle: 'Configure IMDb, Rotten Tomatoes, Metacritic, & Trakt scores',
                        onTap: () => _navigateTo(const MDBListSettingsScreen()),
                      ),
                      Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
                      _buildCategoryTile(
                        icon: Icons.sync_outlined,
                        title: 'Simkl Scrobbling',
                        subtitle: 'Automatic tracking and scrobbling of watched movies & TV shows',
                        onTap: () => _navigateTo(const SimklSettingsScreen()),
                      ),
                      Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.05)),
                      _buildCategoryTile(
                        icon: Icons.person_outline,
                        title: 'Account',
                        subtitle: 'Sign in, Sign out, manage profiles and cloud synchronization',
                        onTap: () => _navigateTo(const AccountSettingsScreen()),
                      ),
                    ],
                  ),
                ),
              ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white30, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
