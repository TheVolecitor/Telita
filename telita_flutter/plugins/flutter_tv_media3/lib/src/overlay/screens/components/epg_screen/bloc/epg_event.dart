part of 'epg_bloc.dart';

abstract class EpgEvent extends Equatable {
  const EpgEvent();

  @override
  List<Object?> get props => [];
}

class EpgStarted extends EpgEvent {
  final String? initialChannelId;
  const EpgStarted({this.initialChannelId});

  @override
  List<Object?> get props => [initialChannelId];
}

class EpgChannelSelected extends EpgEvent {
  final int channelIndex;
  const EpgChannelSelected(this.channelIndex);
}

class EpgProgramSelected extends EpgEvent {
  final int programIndex;
  const EpgProgramSelected(this.programIndex);
}

class EpgPageChanged extends EpgEvent {
  final int pageIndex;
  const EpgPageChanged(this.pageIndex);
}

class EpgTimerTicked extends EpgEvent {}

class EpgDateChanged extends EpgEvent {
  final int dateIndex;
  const EpgDateChanged(this.dateIndex);
}

class EpgScrolled extends EpgEvent {}

class EpgPlayerStateUpdated extends EpgEvent {
  final PlayerState playerState;
  const EpgPlayerStateUpdated(this.playerState);

  @override
  List<Object?> get props => [playerState];
}
