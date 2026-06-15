enum SubtitleSearchStatus { idle, loading, error, success }

/// Represents the complete UI state for the "Find Subtitles" feature.
class FindSubtitlesState {
  /// Determines if the "Find Subtitles" button should be shown at all.
  /// This is typically set once at initialization.
  final bool isVisible;

  /// The normal text for the button (e.g., "Find on SubDB", "Searching...").
  final String? label;

  /// The text to display under the button with additional info.
  final String? stateInfoLabel;

  /// The message to display in case of an error.
  final String? errorMessage;

  /// The current status of the search operation.
  final SubtitleSearchStatus status;

  const FindSubtitlesState({
    this.isVisible = false,
    this.label,
    this.stateInfoLabel,
    this.errorMessage,
    this.status = SubtitleSearchStatus.idle,
  });

  /// Creates a copy of the state with new values.
  FindSubtitlesState copyWith({
    bool? isVisible,
    String? label,
    String? stateInfoLabel,
    String? errorMessage,
    SubtitleSearchStatus? status,
    bool? resetError,
  }) {
    return FindSubtitlesState(
      isVisible: isVisible ?? this.isVisible,
      label: label ?? this.label,
      stateInfoLabel: stateInfoLabel ?? this.stateInfoLabel,
      errorMessage:
          errorMessage ?? (resetError == true ? null : this.errorMessage),
      status: status ?? this.status,
    );
  }

  /// Converts this object to a map.
  Map<String, dynamic> toMap() {
    return {
      'isVisible': isVisible,
      'label': label,
      'stateInfoLabel': stateInfoLabel,
      'error':
          errorMessage, // Keep 'error' key for backward compatibility with native side if needed
      'status': status.name,
    };
  }

  /// Creates an instance from a map.
  factory FindSubtitlesState.fromMap(Map<String, dynamic> map) {
    return FindSubtitlesState(
      isVisible: map['isVisible'] as bool? ?? false,
      label: map['label'] as String?,
      stateInfoLabel: map['stateInfoLabel'] as String?,
      errorMessage: map['error'] as String?,
      status: SubtitleSearchStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SubtitleSearchStatus.idle,
      ),
    );
  }
}
