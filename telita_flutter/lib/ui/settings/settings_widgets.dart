import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

List<Widget> animateStaggeredList(List<Widget> children, {int durationMs = 375, double verticalOffset = 50.0}) {
  return AnimationConfiguration.toStaggeredList(
    duration: Duration(milliseconds: durationMs),
    childAnimationBuilder: (widget) => SlideAnimation(
      verticalOffset: verticalOffset,
      child: FadeInAnimation(
        child: widget,
      ),
    ),
    children: children,
  );
}

Widget buildSectionHeader(BuildContext context, IconData icon, String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class SettingsInfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const SettingsInfoCard({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveColor.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: effectiveColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildToggle({
  required String label,
  String? desc,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
    child: Material(
      color: Colors.transparent,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        focusColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: desc != null ? Text(desc, style: const TextStyle(color: Colors.white30, fontSize: 12)) : null,
        trailing: IgnorePointer(
          child: Switch(
            value: value,
            onChanged: (v) {},
          ),
        ),
        onTap: () => onChanged(!value),
      ),
    ),
  );
}

Widget buildSlider({
  required String label,
  String? desc,
  required double value,
  required double min,
  required double max,
  int? divisions,
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
            Text('${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}$unit', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        TVSlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

Widget buildTVDropdown<T>({
  required BuildContext context,
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

class _TVTextFieldWidget extends StatefulWidget {
  final String label;
  final String? desc;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

  const _TVTextFieldWidget({
    required this.label,
    this.desc,
    required this.value,
    required this.onChanged,
    this.obscureText = false,
    this.onToggleObscure,
  });

  @override
  State<_TVTextFieldWidget> createState() => _TVTextFieldWidgetState();
}

class _TVTextFieldWidgetState extends State<_TVTextFieldWidget> {
  late final TextEditingController _controller;
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
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
  }

  @override
  void didUpdateWidget(covariant _TVTextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          if (widget.desc != null) ...[
            const SizedBox(height: 4),
            Text(widget.desc!, style: const TextStyle(color: Colors.white30, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          TextField(
            focusNode: _node,
            controller: _controller,
            obscureText: widget.obscureText,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter here',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              suffixIcon: widget.onToggleObscure != null ? IconButton(
                icon: Icon(
                  widget.obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: widget.onToggleObscure,
              ) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

Widget buildTextField({
  required String label,
  String? desc,
  required String value,
  required ValueChanged<String> onChanged,
  bool obscureText = false,
  VoidCallback? onToggleObscure,
}) {
  return _TVTextFieldWidget(
    label: label,
    desc: desc,
    value: value,
    onChanged: onChanged,
    obscureText: obscureText,
    onToggleObscure: onToggleObscure,
  );
}

class TVSlider extends StatefulWidget {
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const TVSlider({super.key, required this.value, required this.min, required this.max, this.divisions, required this.onChanged});

  @override
  State<TVSlider> createState() => _TVSliderState();
}

class _TVSliderState extends State<TVSlider> {
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
      divisions: widget.divisions,
      inactiveColor: Colors.white10,
      onChanged: widget.onChanged,
    );
  }
}
