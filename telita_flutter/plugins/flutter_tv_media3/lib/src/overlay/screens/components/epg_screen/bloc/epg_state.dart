part of 'epg_bloc.dart';

class EpgState extends Equatable {
  const EpgState({
    this.status = EpgStatus.initial,
    this.errorMessage,
    this.allChannels = const [],
    this.availableDates = const [],
    this.activeProgramIndex = -1,
    this.selectedChannelIndex = 0,
    this.selectedProgramIndex = 0,
    this.selectedDateIndex = 0,
    this.currentPage = 0,
    this.programIndexToScroll,
  });

  final EpgStatus status;
  final String? errorMessage;
  final List<EpgChannel> allChannels;
  final List<DateTime> availableDates;
  final int activeProgramIndex;
  final int selectedChannelIndex;
  final int selectedProgramIndex;
  final int selectedDateIndex;
  final int currentPage;
  final int? programIndexToScroll;

  EpgChannel? get selectedChannel {
    if (allChannels.isNotEmpty && selectedChannelIndex < allChannels.length) {
      return allChannels[selectedChannelIndex];
    }
    return null;
  }

  EpgProgram? get selectedProgram {
    final channel = selectedChannel;
    if (channel != null &&
        channel.programs.isNotEmpty &&
        selectedProgramIndex < channel.programs.length) {
      return channel.programs[selectedProgramIndex];
    }
    return null;
  }

  bool get hasPrograms => selectedChannel?.programs.isNotEmpty ?? false;

  EpgState copyWith({
    EpgStatus? status,
    String? errorMessage,
    List<EpgChannel>? allChannels,
    List<DateTime>? availableDates,
    int? activeProgramIndex,
    int? selectedChannelIndex,
    int? selectedProgramIndex,
    int? selectedDateIndex,
    int? currentPage,
    int? programIndexToScroll,
  }) {
    return EpgState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      allChannels: allChannels ?? this.allChannels,
      availableDates: availableDates ?? this.availableDates,
      activeProgramIndex: activeProgramIndex ?? this.activeProgramIndex,
      selectedChannelIndex: selectedChannelIndex ?? this.selectedChannelIndex,
      selectedProgramIndex: selectedProgramIndex ?? this.selectedProgramIndex,
      selectedDateIndex: selectedDateIndex ?? this.selectedDateIndex,
      currentPage: currentPage ?? this.currentPage,
      programIndexToScroll: programIndexToScroll,
    );
  }

  @override
  List<Object?> get props => [
    status,
    errorMessage,
    allChannels,
    availableDates,
    activeProgramIndex,
    selectedChannelIndex,
    selectedProgramIndex,
    selectedDateIndex,
    currentPage,
    programIndexToScroll,
  ];
}
