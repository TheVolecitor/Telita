import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/auth.dart';

class ProfileSelectScreen extends StatefulWidget {
  final VoidCallback onDone;

  const ProfileSelectScreen({super.key, required this.onDone});

  @override
  State<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> {
  bool _showPinInput = false;
  AuthProfile? _selectedProfile;
  final _pinCtrl = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  String _error = '';

  @override
  void dispose() {
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _selectProfile(AuthProfile profile) {
    if (profile.hasPin == true) {
      setState(() {
        _selectedProfile = profile;
        _showPinInput = true;
        _error = '';
        _pinCtrl.clear();
      });
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _pinFocus.requestFocus(),
      );
    } else {
      AuthService.instance.selectProfile(profile).then((_) {
        widget.onDone();
      });
    }
  }

  void _submitPin() async {
    if (_pinCtrl.text.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }

    if (_selectedProfile != null) {
      final success = await AuthService.instance.unlockProfile(
        _selectedProfile!.id,
        _pinCtrl.text,
      );
      if (success) {
        await AuthService.instance.selectProfile(_selectedProfile!);
        widget.onDone();
      } else {
        setState(() {
          _error = 'Incorrect PIN';
          _pinCtrl.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = AuthService.instance.value.profiles;

    return PopScope(
      canPop: !_showPinInput,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_showPinInput) {
          setState(() {
            _showPinInput = false;
            _error = '';
            _pinCtrl.clear();
          });
        }
      },
      child: Material(
        color: const Color(0xFF0F172A),
        child: Center(
          child: _showPinInput
              ? _buildPinInput()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Who's watching?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Wrap(
                      spacing: 32,
                      runSpacing: 32,
                      alignment: WrapAlignment.center,
                      children: [
                        ...profiles.map((p) => _buildProfileAvatar(p)),
                        if (profiles.length < 5) _buildAddProfile(),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(AuthProfile profile) {
    return _ProfileAvatarButton(
      profile: profile,
      onTap: () => _selectProfile(profile),
      onLongPress: () => _showProfileOptions(profile),
    );
  }

  Widget _buildAddProfile() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          InkWell(
            onTap: _addProfile,
            borderRadius: BorderRadius.circular(60),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.add, size: 48, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Profile',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _addProfile() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Profile', style: TextStyle(color: Colors.white)),
        content: Focus(
          onKeyEvent: (node, event) {
            if (MediaQuery.of(context).viewInsets.bottom > 0) {
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowRight ||
                    event.logicalKey == LogicalKeyboardKey.arrowUp ||
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  return KeyEventResult.skipRemainingHandlers;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            autofocus: true,
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Profile Name',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await AuthService.instance.addProfile(ctrl.text.trim());
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions(AuthProfile profile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            '${profile.name} Options',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.white),
                title: Text(
                  profile.hasPin == true ? 'Change PIN' : 'Set PIN',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _changeProfilePin(profile);
                },
              ),
              if (profile.hasPin == true)
                ListTile(
                  leading: const Icon(
                    Icons.lock_open_outlined,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Remove PIN',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) =>
                          _ChangePinDialog(profile: profile, isRemoving: true),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.image_outlined, color: Colors.white),
                title: const Text(
                  'Change Avatar',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _changeAvatar(profile);
                },
              ),
              if (AuthService.instance.value.profiles.length > 1)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete Profile',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteProfile(profile);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteProfile(AuthProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete Profile',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${profile.name}? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.instance.deleteProfile(profile.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _changeAvatar(AuthProfile profile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Choose Avatar',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 15,
              itemBuilder: (context, idx) {
                final avatarUrl = 'assets/pfps/${idx + 1}.png';
                return InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await AuthService.instance.updateProfile(
                      profile.id,
                      avatarUrl: avatarUrl,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(avatarUrl, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        );
      },
    );
  }

  void _changeProfilePin(AuthProfile profile) {
    showDialog(
      context: context,
      builder: (context) => _ChangePinDialog(profile: profile),
    );
  }

  Widget _buildPinInput() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter PIN for ${_selectedProfile?.name}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            (kIsWeb ||
                    (!kIsWeb &&
                        (Platform.isWindows ||
                            Platform.isMacOS ||
                            Platform.isLinux)) ||
                    MediaQuery.of(context).orientation == Orientation.portrait)
                ? StandardPinInput(
                    controller: _pinCtrl,
                    onSubmitted: _submitPin,
                    onCancel: () {
                      setState(() {
                        _showPinInput = false;
                        _error = '';
                      });
                    },
                  )
                : DPadPinInput(
                    controller: _pinCtrl,
                    onSubmitted: _submitPin,
                    onCancel: () {
                      setState(() {
                        _showPinInput = false;
                        _error = '';
                      });
                    },
                  ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatarButton extends StatefulWidget {
  final AuthProfile profile;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProfileAvatarButton({
    required this.profile,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<_ProfileAvatarButton> {
  bool _isFocused = false;
  Timer? _longPressTimer;
  bool _longPressHandled = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _handleKeyDown() {
    if (_longPressTimer != null) return;
    _longPressHandled = false;
    _longPressTimer = Timer(const Duration(milliseconds: 600), () {
      _longPressHandled = true;
      if (widget.onLongPress != null) widget.onLongPress!();
    });
  }

  void _handleKeyUp() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Focus(
            onFocusChange: (hasFocus) {
              setState(() {
                _isFocused = hasFocus;
              });
              if (!hasFocus) _handleKeyUp();
            },
            onKeyEvent: (node, event) {
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                if (event is KeyDownEvent) {
                  _handleKeyDown();
                  return KeyEventResult.handled;
                } else if (event is KeyRepeatEvent) {
                  return KeyEventResult.handled;
                } else if (event is KeyUpEvent) {
                  _handleKeyUp();
                  if (!_longPressHandled) {
                    widget.onTap();
                  }
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: InkWell(
              onHover: (hasHover) {
                setState(() {
                  _isFocused = hasHover;
                });
              },
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onSecondaryTap: widget.onLongPress,
              borderRadius: BorderRadius.circular(60),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: AnimatedScale(
                scale: _isFocused ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white12,
                    border: Border.all(
                      color: _isFocused
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3.0,
                    ),
                    image: widget.profile.avatarUrl != null
                        ? DecorationImage(
                            image: widget.profile.avatarUrl!.startsWith('http')
                                ? NetworkImage(widget.profile.avatarUrl!)
                                      as ImageProvider
                                : AssetImage(
                                    widget.profile.avatarUrl!.startsWith('/')
                                        ? 'assets${widget.profile.avatarUrl}'
                                        : widget.profile.avatarUrl!,
                                  ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.profile.avatarUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 64,
                          color: Colors.white54,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.profile.name,
            style: TextStyle(
              color: _isFocused ? Colors.white : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.profile.hasPin == true) ...[
            const SizedBox(height: 8),
            Icon(
              Icons.lock,
              size: 16,
              color: _isFocused ? Colors.white : Colors.white54,
            ),
          ],
        ],
      ),
    );
  }
}

class DPadPinInput extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final VoidCallback onSubmitted;
  final VoidCallback onCancel;

  const DPadPinInput({
    super.key,
    required this.controller,
    this.maxLength = 4,
    required this.onSubmitted,
    required this.onCancel,
  });

  void _addDigit(String digit) {
    if (controller.text.length < maxLength) {
      controller.text += digit;
      if (controller.text.length == maxLength) {
        onSubmitted();
      }
    }
  }

  void _removeDigit() {
    if (controller.text.isNotEmpty) {
      controller.text = controller.text.substring(
        0,
        controller.text.length - 1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.white54),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(maxLength, (index) {
                    final hasDigit = index < controller.text.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 52,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasDigit
                              ? const Color(0xFF6C63FF)
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          hasDigit ? '•' : '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(width: 48),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gamepad,
                        color: Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "D-PAD CONTROL",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 280,
                    child: Column(
                      children: [
                        _PinRow(
                          labels: const ['1', '2', '3'],
                          onInput: _addDigit,
                        ),
                        _PinRow(
                          labels: const ['4', '5', '6'],
                          onInput: _addDigit,
                        ),
                        _PinRow(
                          labels: const ['7', '8', '9'],
                          onInput: _addDigit,
                        ),
                        _PinRow(
                          labels: const ['Del', '0', 'Clear'],
                          onInput: _addDigit,
                          onBackspace: _removeDigit,
                          onClear: () => controller.clear(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PinRow extends StatefulWidget {
  final List<String> labels;
  final ValueChanged<String> onInput;
  final VoidCallback? onClear;
  final VoidCallback? onBackspace;

  const _PinRow({
    required this.labels,
    required this.onInput,
    this.onClear,
    this.onBackspace,
  });

  @override
  State<_PinRow> createState() => _PinRowState();
}

class _PinRowState extends State<_PinRow> {
  bool _isFocused = false;

  void _handle(int index) {
    final label = widget.labels[index];
    if (label == 'Del')
      widget.onBackspace?.call();
    else if (label == 'Clear')
      widget.onClear?.call();
    else
      widget.onInput(label);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _handle(0);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _handle(2);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _handle(1);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
              widget.labels[1] == '2') {
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              widget.labels[1] == '0') {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: _isFocused
              ? const Color(0xFF6C63FF).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: _isFocused ? const Color(0xFF6C63FF) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel(widget.labels[0], 0),
            _buildLabel(widget.labels[1], 1),
            _buildLabel(widget.labels[2], 2),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, int position) {
    IconData? icon;
    if (text == 'Del') icon = Icons.backspace_outlined;
    if (text == 'Clear') icon = Icons.clear;

    Widget content = icon != null
        ? Icon(
            icon,
            color: _isFocused ? Colors.white : Colors.white70,
            size: 24,
          )
        : Text(
            text,
            style: TextStyle(
              color: _isFocused ? Colors.white : Colors.white70,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          );

    return SizedBox(
      width: 76,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isFocused && position == 1)
            Icon(
              Icons.circle,
              color: const Color(0xFF6C63FF).withOpacity(0.5),
              size: 40,
            ),

          if (_isFocused && position == 0)
            const Positioned(
              left: 0,
              child: Icon(Icons.arrow_left, color: Color(0xFF6C63FF), size: 24),
            ),

          if (_isFocused && position == 2)
            const Positioned(
              right: 0,
              child: Icon(
                Icons.arrow_right,
                color: Color(0xFF6C63FF),
                size: 24,
              ),
            ),

          Center(child: content),
        ],
      ),
    );
  }
}

class _ChangePinDialog extends StatefulWidget {
  final AuthProfile profile;
  final bool isRemoving;
  const _ChangePinDialog({required this.profile, this.isRemoving = false});
  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  int _step = 0;
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.profile.hasPin != true) _step = 1;
  }

  void _submit() async {
    if (widget.isRemoving) {
      if (_curCtrl.text.length == 4) {
        Navigator.pop(context);
        await AuthService.instance.updateProfile(
          widget.profile.id,
          currentPin: _curCtrl.text,
          pin: "",
        );
      }
      return;
    }

    if (_step == 0) {
      if (_curCtrl.text.length == 4) {
        setState(() {
          _step = 1;
          _error = '';
        });
      }
    } else {
      if (_newCtrl.text.length == 4) {
        Navigator.pop(context);
        await AuthService.instance.updateProfile(
          widget.profile.id,
          currentPin: widget.profile.hasPin == true ? _curCtrl.text : null,
          pin: _newCtrl.text,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isRemoving
        ? 'Enter PIN to Remove'
        : widget.profile.hasPin == true
        ? (_step == 0 ? 'Enter Current PIN' : 'Enter New PIN')
        : 'Set New PIN';

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            (kIsWeb ||
                    (!kIsWeb &&
                        (Platform.isWindows ||
                            Platform.isMacOS ||
                            Platform.isLinux)) ||
                    MediaQuery.of(context).orientation == Orientation.portrait)
                ? StandardPinInput(
                    controller: _step == 0 ? _curCtrl : _newCtrl,
                    onSubmitted: _submit,
                    onCancel: () => Navigator.pop(context),
                  )
                : DPadPinInput(
                    controller: _step == 0 ? _curCtrl : _newCtrl,
                    onSubmitted: _submit,
                    onCancel: () => Navigator.pop(context),
                  ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class StandardPinInput extends StatefulWidget {
  final TextEditingController controller;
  final int maxLength;
  final VoidCallback onSubmitted;
  final VoidCallback onCancel;

  const StandardPinInput({
    super.key,
    required this.controller,
    this.maxLength = 4,
    required this.onSubmitted,
    required this.onCancel,
  });

  @override
  State<StandardPinInput> createState() => _StandardPinInputState();
}

class _StandardPinInputState extends State<StandardPinInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, size: 48, color: Colors.white54),
        const SizedBox(height: 24),
        Stack(
          alignment: Alignment.center,
          children: [
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final text = widget.controller.text;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.maxLength, (index) {
                    final hasDigit = index < text.length;
                    final isActive =
                        _isFocused &&
                        (index == text.length ||
                            (index == widget.maxLength - 1 &&
                                text.length == widget.maxLength));
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 52,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasDigit
                              ? const Color(0xFF6C63FF)
                              : (isActive ? Colors.white70 : Colors.white24),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          hasDigit ? '•' : '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  focusNode: _focusNode,
                  controller: widget.controller,
                  autofocus: true,
                  maxLength: widget.maxLength,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    if (value.length == widget.maxLength) {
                      widget.onSubmitted();
                    }
                  },
                  onSubmitted: (_) => widget.onSubmitted(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
