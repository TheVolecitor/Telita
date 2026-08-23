import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/settings.dart';
import 'settings_widgets.dart';

class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key});

  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _loadInitialPath();
  }

  Future<void> _loadInitialPath() async {
    final cfgPath = SettingsService.instance.value.downloadPath;
    if (cfgPath.isNotEmpty) {
      setState(() {
        _currentPath = cfgPath;
      });
    } else {
      // Fallback to default
      final dir = await getDownloadsDirectory(); 
      final target = dir != null ? dir.path : "";
      setState(() {
        _currentPath = target;
      });
      // Save it back to settings so it's initialized
      SettingsService.instance.set('downloadPath', target);
    }
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Download Folder',
    );

    if (selectedDirectory != null) {
      SettingsService.instance.set('downloadPath', selectedDirectory);
      setState(() {
        _currentPath = selectedDirectory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: animateStaggeredList([
            const Text(
              'Downloads',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your offline media library.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            // Path Selector
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                title: const Text('Download Location', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _currentPath.isEmpty ? 'Loading...' : _currentPath,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                  ),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: _pickDirectory,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Change'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
