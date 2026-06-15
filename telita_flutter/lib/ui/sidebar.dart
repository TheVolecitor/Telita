import 'package:flutter/material.dart';

enum Screen { home, addons, settings }

class Sidebar extends StatefulWidget {
  final Screen currentScreen;
  final ValueChanged<Screen> onNavigate;
  final VoidCallback onManageProfile;
  final bool isGuest;
  final String? profileName;
  final String? avatarUrl;

  const Sidebar({
    super.key,
    required this.currentScreen,
    required this.onNavigate,
    required this.onManageProfile,
    this.isGuest = true,
    this.profileName,
    this.avatarUrl,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isExpanded = false;
  final FocusNode _discoverFocusNode = FocusNode();

  @override
  void dispose() {
    _discoverFocusNode.dispose();
    super.dispose();
  }

  Widget _buildNavItem(BuildContext context, Screen screen, String title, IconData icon, IconData activeIcon, {FocusNode? focusNode}) {
    final isActive = widget.currentScreen == screen;
    final color = isActive ? Colors.white : Colors.white54;
    final bgColor = isActive ? Colors.white.withOpacity(0.1) : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onNavigate(screen),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 12 : 0, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(isActive ? activeIcon : icon, color: color, size: 20),
              if (_isExpanded) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Focus(
        canRequestFocus: false, // Crucial: lets the inner InkWells receive focus instead of the container!
        onFocusChange: (hasFocus) {
          if (hasFocus && !_isExpanded) {
            _discoverFocusNode.requestFocus();
          }
          setState(() {
            _isExpanded = hasFocus;
          });
        },
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: _isExpanded ? 240 : 56,
        color: Colors.transparent, // Submerged
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 24),
        child: ClipRect(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: _isExpanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    // Logo
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.only(left: _isExpanded ? 12 : 0),
                      child: Row(
                        mainAxisAlignment: _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/logo.png', width: 36, height: 36, color: Colors.white70, colorBlendMode: BlendMode.srcIn),
                        if (_isExpanded) ...[
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              'Telita',
                              overflow: TextOverflow.clip,
                              softWrap: false,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    ),
                    const SizedBox(height: 40),
                    
                    if (_isExpanded)
                      const Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 12),
                        child: Text(
                          'Menu',
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 26),

                    _buildNavItem(context, Screen.home, 'Discover', Icons.explore_outlined, Icons.explore, focusNode: _discoverFocusNode),
                    const SizedBox(height: 8),
                    _buildNavItem(context, Screen.addons, 'Addons', Icons.extension_outlined, Icons.extension),
                    const SizedBox(height: 8),
                    _buildNavItem(context, Screen.settings, 'Settings', Icons.settings_outlined, Icons.settings),

                    const Spacer(),

                    // Profile Card
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.onManageProfile,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 8 : 6, vertical: 10),
                          child: Row(
                            mainAxisAlignment: _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                            children: [
                              if (!_isExpanded) const SizedBox(width: 4),
                              CircleAvatar(
                                radius: _isExpanded ? 14 : 12, // Reduced to 14 from 16 to prevent overflow
                                backgroundColor: Colors.white24,
                                backgroundImage: widget.avatarUrl != null 
                                    ? (widget.avatarUrl!.startsWith('http') 
                                        ? NetworkImage(widget.avatarUrl!) as ImageProvider
                                        : AssetImage('assets/pfps/${widget.avatarUrl!.split('/').last}'))
                                    : null,
                                child: widget.avatarUrl == null
                                    ? (widget.isGuest
                                        ? Icon(Icons.person_outline, color: Colors.white, size: _isExpanded ? 18 : 16)
                                        : Text(
                                            (widget.profileName?.isNotEmpty == true ? widget.profileName!.substring(0, 2) : 'ME').toUpperCase(),
                                            style: TextStyle(color: Colors.white, fontSize: _isExpanded ? 11 : 9, fontWeight: FontWeight.bold),
                                          ))
                                    : null,
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(width: 8), // Reduced to 8 from 12
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.isGuest ? 'Guest' : (widget.profileName ?? 'Signed In'),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), // slightly smaller text
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        softWrap: false,
                                      ),
                                      Text(
                                        widget.isGuest ? 'Local mode' : 'Cloud Sync on',
                                        overflow: TextOverflow.clip,
                                        softWrap: false,
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ), // Column
              ),
            ],
          ), // CustomScrollView
        ), // ClipRect
      ), // AnimatedContainer
      ), // Focus
    ); // FocusTraversalGroup
  }
}
