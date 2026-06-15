import 'package:flutter/material.dart';

import '../../../../app_theme/app_theme.dart';
import '../../../bloc/overlay_ui_bloc.dart';

void showSideSheet({
  required BuildContext context,
  required OverlayUiBloc bloc,
  required Widget body,
  bool fromLeft = false,
  double widthFactor = 0.4,
  Duration duration = const Duration(milliseconds: 150),
  Color barrierColor = Colors.black54,
  bool dismissible = true,
}) async {
  if (bloc.state.sideSheetOpen) {
    Navigator.of(context, rootNavigator: true).pop();
    bloc.add(const SetSideSheetState(isOpen: false));
    await Future.delayed(duration);
  }

  bloc.add(const SetSideSheetState(isOpen: true));
  if (context.mounted) {
    showGeneralDialog(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Material(
            color: AppTheme.backgroundColor,
            elevation: 12,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * widthFactor,
              height: double.infinity,
              child: body,
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: Offset(fromLeft ? -1 : 1, 0),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(position: offsetAnimation, child: child);
      },
    ).then((_) {
      bloc.add(const SetSideSheetState(isOpen: false));
    });
  }
}
