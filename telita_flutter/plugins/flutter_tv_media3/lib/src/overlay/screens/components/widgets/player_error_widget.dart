import 'package:flutter/material.dart';
import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';

import '../../../../app_theme/app_theme.dart';

class PlayerErrorWidget extends StatefulWidget {
  const PlayerErrorWidget({
    super.key,
    required this.lastError,
    this.errorCode,
    required this.onExit,
    this.onClose,
    this.onNext,
    this.onOpen,
    this.onRetry,
    this.onSwitchToVLC,
  });

  final String lastError;
  final String? errorCode;
  final VoidCallback onExit;
  final VoidCallback? onNext;
  final VoidCallback? onClose;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;
  final VoidCallback? onSwitchToVLC;

  @override
  State<PlayerErrorWidget> createState() => _PlayerErrorWidgetState();
}

class _PlayerErrorWidgetState extends State<PlayerErrorWidget> {
  final focusExit = FocusNode();
  final focusNext = FocusNode();
  final focusClose = FocusNode();
  final focusRetry = FocusNode();
  final focusVLC = FocusNode();

  @override
  void initState() {
    if (widget.onOpen != null) widget.onOpen!();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onRetry != null) {
        FocusScope.of(context).requestFocus(focusRetry);
      } else if (widget.onClose != null) {
        FocusScope.of(context).requestFocus(focusClose);
      } else if (widget.onNext != null) {
        FocusScope.of(context).requestFocus(focusNext);
      } else {
        FocusScope.of(context).requestFocus(focusExit);
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: AppTheme.borderRadius,
          ),
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.errColor,
                size: 64,
              ),
              const SizedBox(height: 16),
              if (widget.errorCode != null)
                Text(
                  widget.errorCode!,
                  style: const TextStyle(
                    color: AppTheme.errColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Text(
                widget.lastError,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 140,
                    child: OutlinedButton(
                      focusNode: focusExit,
                      onPressed: widget.onExit,
                      child: Text(OverlayLocalizations.get('exit')),
                    ),
                  ),
                  if (widget.onRetry != null)
                    SizedBox(
                      width: 140,
                      child: OutlinedButton(
                        focusNode: focusRetry,
                        onPressed: widget.onRetry,
                        child: const Text('Retry'),
                      ),
                    ),
                  if (widget.onSwitchToVLC != null)
                    SizedBox(
                      width: 180,
                      child: OutlinedButton(
                        focusNode: focusVLC,
                        onPressed: widget.onSwitchToVLC,
                        child: const Text('Switch to VLC'),
                      ),
                    ),
                  if (widget.onClose != null)
                    SizedBox(
                      width: 140,
                      child: OutlinedButton(
                        focusNode: focusClose,
                        onPressed: widget.onClose,
                        child: Text(OverlayLocalizations.get('close')),
                      ),
                    ),
                  if (widget.onNext != null)
                    SizedBox(
                      width: 140,
                      child: OutlinedButton(
                        focusNode: focusNext,
                        onPressed: widget.onNext,
                        child: Text(OverlayLocalizations.get('next')),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
