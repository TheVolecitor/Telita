import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app_theme/app_theme.dart';
import '../../../bloc/overlay_ui_bloc.dart';

class CustomInfoTextWidget extends StatelessWidget {
  const CustomInfoTextWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverlayUiBloc, OverlayUiState>(
      buildWhen:
          (previous, current) =>
              previous.customInfoText != current.customInfoText,
      builder: (context, state) {
        if (state.customInfoText == null || state.customInfoText!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(
          state.customInfoText!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.colorSecondary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
