import 'package:flutter/material.dart';
import '../../core/auth.dart';
import 'settings_widgets.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<AuthState>(
          valueListenable: AuthService.instance,
          builder: (context, authState, _) {
            final title = authState.isGuest ? 'Guest Mode' : (authState.user?.email ?? 'Signed In');
            final desc = authState.isGuest ? 'Not syncing to cloud' : 'Profile: ${authState.profile?.name ?? 'None'}';

            return ListView(
              padding: const EdgeInsets.all(32.0),
              children: animateStaggeredList([
                Container(
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
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
