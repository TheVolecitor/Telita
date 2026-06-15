import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app_theme/app_theme.dart';

class EditTextFormWidget extends StatefulWidget {
  const EditTextFormWidget({
    required this.title,
    required this.defaultValue,
    this.newValue,
    required this.hintText,
    required this.saveValue,
    this.keyboardType,
    this.maxLines,
    this.onChanged,
    required this.focusNode,
    super.key,
  });
  final String title;
  final String? defaultValue;
  final String? newValue;
  final String hintText;
  final Function(String) saveValue;
  final TextInputType? keyboardType;
  final int? maxLines;
  final void Function(String)? onChanged;
  final FocusNode focusNode;
  @override
  State<EditTextFormWidget> createState() => _EditJackettSettingsWidgetState();
}

class _EditJackettSettingsWidgetState extends State<EditTextFormWidget> {
  late String defaultValue;
  bool isFocusKeyboard = false;
  TextEditingController textEditingController = TextEditingController();
  FocusNode focusNodeForm = FocusNode();
  late FocusNode focusNodeButton;

  @override
  void initState() {
    focusNodeButton = widget.focusNode;
    defaultValue = widget.defaultValue ?? '';
    textEditingController.text =
        widget.newValue != null ? widget.newValue! : defaultValue;
    super.initState();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    focusNodeButton.dispose();
    focusNodeForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child:
          isFocusKeyboard == false
              ? ListTile(
                focusColor: AppTheme.focusColor,
                trailing:
                    textEditingController.text == defaultValue
                        ? const Icon(Icons.search)
                        : const Icon(Icons.search_off),
                focusNode: focusNodeButton,
                title: Text(widget.title),
                subtitle:
                    textEditingController.text.isEmpty
                        ? null
                        : Text(
                          widget.keyboardType == TextInputType.visiblePassword
                              ? textEditingController.text.replaceAll(
                                RegExp(r'.'),
                                '*',
                              )
                              : textEditingController.text,
                          maxLines: widget.maxLines,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                onTap:
                    textEditingController.text == defaultValue
                        ? keyboardFocusChange
                        : () {
                          textEditingController.clear();
                          defaultValue = textEditingController.text;
                          setState(() {});
                          widget.saveValue(textEditingController.text);
                        },
                titleTextStyle: Theme.of(context).textTheme.titleLarge,
              )
              : CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter):
                      keyboardFocusChange,
                  const SingleActivator(LogicalKeyboardKey.space):
                      keyboardFocusChange,
                  const SingleActivator(LogicalKeyboardKey.select):
                      keyboardFocusChange,
                  const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
                      keyboardFocusChange,
                  const SingleActivator(LogicalKeyboardKey.arrowUp):
                      keyboardFocusChange,
                  const SingleActivator(LogicalKeyboardKey.arrowDown):
                      keyboardFocusChange,
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: TextFormField(
                    focusNode: focusNodeForm,
                    autofocus: true,
                    controller: textEditingController,
                    textInputAction: TextInputAction.go,
                    onEditingComplete: keyboardFocusChange,
                    keyboardType: widget.keyboardType,
                    decoration: InputDecoration(hintText: widget.hintText),
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
    );
  }

  void keyboardFocusChange() {
    setState(() {
      isFocusKeyboard = !isFocusKeyboard;
      isFocusKeyboard == true
          ? focusNodeForm.requestFocus()
          : focusNodeButton.requestFocus();
    });
  }
}
