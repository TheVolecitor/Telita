import 'package:flutter/material.dart';

import '../../../../../app_theme/app_theme.dart';

class ChannelLogoWidget extends StatelessWidget {
  final String? logoUrl;
  final double dimension;

  const ChannelLogoWidget({this.logoUrl, this.dimension = 40, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: dimension,
      height: dimension,
      child: ClipRRect(
        borderRadius: AppTheme.borderRadius,
        child: Container(
          color: AppTheme.focusColor,
          child:
              logoUrl != null
                  ? Image.network(
                    logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (context, error, stackTrace) => const Icon(
                          Icons.tv,
                          color: AppTheme.colorSecondary,
                          size: 24,
                        ),
                    loadingBuilder:
                        (context, widget, chunk) =>
                            chunk == null
                                ? widget
                                : Icon(
                                  Icons.tv,
                                  color: AppTheme.colorSecondary,
                                  size: dimension * 0.6,
                                ),
                  )
                  : Icon(
                    Icons.tv,
                    color: AppTheme.colorSecondary,
                    size: dimension * 0.6,
                  ),
        ),
      ),
    );
  }
}
