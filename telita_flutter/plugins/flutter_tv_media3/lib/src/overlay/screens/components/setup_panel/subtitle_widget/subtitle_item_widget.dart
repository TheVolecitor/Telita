import 'package:flutter/material.dart';
import '../../../../../app_theme/app_theme.dart';
import '../../../../../entity/find_subtitles_state.dart';
import '../../../../../entity/media_track.dart';
import '../../../../../utils/string_utils.dart';
import '../../widgets/marquee_title_widget.dart';

class SubtitleItemWidget extends StatelessWidget {
  const SubtitleItemWidget({
    super.key,
    required this.track,
    required this.index,
    required this.isFocused,
    this.searchStatus = SubtitleSearchStatus.idle,
    this.stateInfoLabel,
    this.onTap,
  });

  final SubtitleTrack track;
  final int index;
  final bool isFocused;
  final SubtitleSearchStatus searchStatus;
  final String? stateInfoLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = track.isSelected == true;
    final Color backgroundColor =
        isFocused
            ? Colors.white.withOpacity(0.15)
            : isSelected
            ? AppTheme.focusColor.withOpacity(0.15)
            : Colors.white.withOpacity(0.02);

    return AnimatedScale(
      scale: isFocused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused ? Colors.white : (isSelected ? AppTheme.focusColor : Colors.transparent),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  SizedBox(
                width: 40,
                height: 40,
                child: _buildIcon(track, isSelected, isFocused),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MarqueeWidget(
                  text: StringUtils.getSubtitleTrackLabel(
                    track: track,
                    index: index,
                  ),
                  focus: isFocused,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isFocused || isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                      color:
                          isFocused ? Colors.white : (isSelected ? AppTheme.focusColor : Colors.white70),
                  ),
                ),
              ),
              if (stateInfoLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    stateInfoLabel!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isFocused ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              if (track.isExternal == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(Icons.file_download, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
      );
  }

  Widget _buildIcon(SubtitleTrack track, bool isSelected, bool isFocused) {
    final color = isFocused || isSelected ? Colors.white : Colors.white70;

    if (track.id == '-2') {
      switch (searchStatus) {
        case SubtitleSearchStatus.loading:
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: const CircularProgressIndicator(color: Colors.white70),
            ),
          );
        case SubtitleSearchStatus.error:
          return Icon(Icons.error_outline, size: 40, color: color);
        default:
          return Icon(Icons.search, size: 40, color: color);
      }
    }

    if (track.index == -1) {
      return Icon(Icons.subtitles_off_outlined, size: 40, color: color);
    }
    return Icon(
      isSelected ? Icons.subtitles : Icons.subtitles_outlined,
      size: 40,
      color: color,
    );
  }
}

