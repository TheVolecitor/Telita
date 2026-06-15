import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app_theme/app_theme.dart';
import '../../../../bloc/overlay_ui_bloc.dart';

class StringSettingsWidget extends StatelessWidget {
  final VoidCallback leftCallback;
  final VoidCallback rightCallback;
  final VoidCallback enterCallback;
  final String valueTitle;
  final String title;
  final bool autofocus;
  final OverlayUiBloc bloc;
  const StringSettingsWidget({
    super.key,
    required this.leftCallback,
    required this.rightCallback,
    required this.enterCallback,
    required this.valueTitle,
    required this.title,
    this.autofocus = false,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<OverlayUiBloc, OverlayUiState, bool>(
      bloc: bloc,
      selector: (state) => state.isTouch,
      builder: (context, isTouch) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): leftCallback,
            const SingleActivator(LogicalKeyboardKey.arrowRight): rightCallback,
          },
          child: ListTile(
            autofocus: autofocus,
            onTap: enterCallback,
            title: Text(title),
            focusColor: AppTheme.focusColor,
            trailing:
                isTouch
                    ? null
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_left, color: AppTheme.fullFocusColor),
                        Text(
                          valueTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Icon(Icons.arrow_right, color: AppTheme.fullFocusColor),
                      ],
                    ),
            subtitle:
                isTouch
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: leftCallback,
                          icon: Icon(
                            Icons.arrow_left,
                            color: AppTheme.fullFocusColor,
                          ),
                        ),
                        Text(
                          valueTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          onPressed: rightCallback,
                          icon: Icon(
                            Icons.arrow_right,
                            color: AppTheme.fullFocusColor,
                          ),
                        ),
                      ],
                    )
                    : null,
            titleTextStyle: Theme.of(context).textTheme.titleLarge,
          ),
        );
      },
    );
  }
}
