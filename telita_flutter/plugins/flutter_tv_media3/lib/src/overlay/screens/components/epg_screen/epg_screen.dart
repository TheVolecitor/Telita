import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../../app_theme/app_theme.dart';
import '../../../../entity/epg_channel.dart';
import '../../../bloc/overlay_ui_bloc.dart';
import '../widgets/clock_widget.dart';
import 'bloc/epg_bloc.dart';
import 'package:flutter_tv_media3/src/overlay/media_ui_service/media3_ui_controller.dart';
import 'widgets/channels_list_view.dart';
import 'widgets/epg_date_selector.dart';
import 'widgets/epg_page_indicator.dart';
import 'widgets/navigation_hints.dart';
import 'widgets/program_details_view.dart';
import 'widgets/programs_list_view.dart';

class EpgScreen extends StatelessWidget {
  final String initialChannelId;
  final int initialPage;
  final OverlayUiBloc bloc;
  final ValueChanged<EpgChannel> onChannelLaunch;
  final Locale deviceLocale;
  final Media3UiController controller;

  const EpgScreen({
    super.key,
    required this.controller,
    required this.initialChannelId,
    this.initialPage = 1,
    required this.onChannelLaunch,
    required this.deviceLocale,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) =>
              EpgBloc(media3UiController: controller, initialPage: initialPage)
                ..add(EpgStarted(initialChannelId: initialChannelId)),
      child: BlocBuilder<EpgBloc, EpgState>(
        builder: (context, state) {
          if (state.status == EpgStatus.loading ||
              state.status == EpgStatus.initial) {
            return Center(
              child: Image.asset(
                'assets/loading.gif',
                width: 60,
                height: 60,
                color: Colors.white70,
                colorBlendMode: BlendMode.srcIn,
              ),
            );
          }
          if (state.status == EpgStatus.failure) {
            return Center(
              child: Text(
                '${OverlayLocalizations.get('errorPrefix')}${state.errorMessage}',
              ),
            );
          }

          return EpgView(
            key: ValueKey(state.hasPrograms),
            onChannelLaunch: onChannelLaunch,
            deviceLocale: deviceLocale,
            hasPrograms: state.hasPrograms,
            bloc: bloc,
          );
        },
      ),
    );
  }
}

class EpgView extends StatefulWidget {
  final ValueChanged<EpgChannel> onChannelLaunch;
  final Locale deviceLocale;
  final bool hasPrograms;
  final OverlayUiBloc bloc;
  const EpgView({
    super.key,
    required this.onChannelLaunch,
    required this.deviceLocale,
    required this.hasPrograms,
    required this.bloc,
  });

  @override
  State<EpgView> createState() => _EpgViewState();
}

class _EpgViewState extends State<EpgView> with TickerProviderStateMixin {
  late PageController _pageController;
  late TabController _tabController;
  final FocusNode _pageFocusNode = FocusNode();
  late final List<FocusNode> _columnFocusNodes;
  late final List<String> _pageTitles;
  late final int _pageCount;

  final ValueNotifier<bool> _canScrollUp = ValueNotifier(false);
  final ValueNotifier<bool> _canScrollDown = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting(widget.deviceLocale.toLanguageTag());
    final bloc = context.read<EpgBloc>();

    _pageCount = widget.hasPrograms ? 3 : 2;
    _pageTitles =
        widget.hasPrograms
            ? [
              OverlayLocalizations.get('channels_title'),
              OverlayLocalizations.get('programs_title'),
              OverlayLocalizations.get('details_title'),
            ]
            : [
              OverlayLocalizations.get('channels_title'),
              OverlayLocalizations.get('programs_title'),
            ];
    _columnFocusNodes = List.generate(_pageCount, (index) => FocusNode());

    _pageController = PageController(initialPage: bloc.state.currentPage);
    _tabController = TabController(
      length: _pageCount,
      vsync: this,
      initialIndex: bloc.state.currentPage,
    );

    _pageController.addListener(() {
      if (_pageController.page != null) {
        _tabController.index = _pageController.page!.round();
      }
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestFocusForPage(bloc.state.currentPage);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    _pageFocusNode.dispose();
    for (var node in _columnFocusNodes) {
      node.dispose();
    }
    _canScrollUp.dispose();
    _canScrollDown.dispose();
    super.dispose();
  }

  void _requestFocusForPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < _columnFocusNodes.length) {
      _columnFocusNodes[pageIndex].requestFocus();
    } else {
      _pageFocusNode.requestFocus();
    }
  }

  void _move(BuildContext context, int direction) {
    final bloc = context.read<EpgBloc>();
    final currentPage = bloc.state.currentPage;
    int newPage;

    if (direction == -1) {
      // Left arrow
      newPage = (currentPage - 1 + _pageCount) % _pageCount;
    } else {
      // Right arrow
      newPage = (currentPage + 1) % _pageCount;
    }

    if (newPage != currentPage) {
      bloc.add(EpgPageChanged(newPage));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTouch = widget.bloc.state.isTouch;
    final epgBloc = context.read<EpgBloc>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: BlocConsumer<EpgBloc, EpgState>(
          listenWhen:
              (previous, current) =>
                  previous.currentPage != current.currentPage,
          listener: (context, state) {
            if (_pageController.hasClients &&
                _pageController.page?.round() != state.currentPage) {
              _pageController.animateToPage(
                state.currentPage,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            _requestFocusForPage(state.currentPage);
          },
          builder: (context, state) {
            return CallbackShortcuts(
              bindings: {
                LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                    () => _move(context, -1),
                LogicalKeySet(LogicalKeyboardKey.arrowRight):
                    () => _move(context, 1),
              },
              child: Focus(
                focusNode: _pageFocusNode,
                child: Column(
                  children: [
                    if (isTouch)
                      Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  widget.bloc.add(
                                    const SetSideSheetState(isOpen: false),
                                  );
                                  widget.bloc.add(
                                    SetActivePanel(
                                      playerPanel: PlayerPanel.touchOverlay,
                                    ),
                                  );
                                },
                              ),
                              const Expanded(
                                child: Center(child: ClockWidget()),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  widget.bloc.add(
                                    const SetSideSheetState(isOpen: false),
                                  );
                                },
                              ),
                            ],
                          ),
                          EpgPageIndicator(
                            tabController: _tabController,
                            tabs:
                                _pageTitles
                                    .map((title) => Tab(text: title))
                                    .toList(),
                            deviceLocale: widget.deviceLocale,
                            showClock: false,
                          ),
                        ],
                      )
                    else
                      EpgPageIndicator(
                        tabController: _tabController,
                        tabs:
                            _pageTitles
                                .map((title) => Tab(text: title))
                                .toList(),
                        deviceLocale: widget.deviceLocale,
                        showClock: true,
                      ),
                    if (state.currentPage == 1)
                      EpgDateSelector(
                        bloc: widget.bloc,
                        dates: state.availableDates,
                        selectedIndex: state.selectedDateIndex,
                        onPreviousDay: () {
                          if (state.selectedDateIndex > 0) {
                            epgBloc.add(
                              EpgDateChanged(state.selectedDateIndex - 1),
                            );
                          }
                        },
                        onNextDay: () {
                          if (state.selectedDateIndex <
                              state.availableDates.length - 1) {
                            epgBloc.add(
                              EpgDateChanged(state.selectedDateIndex + 1),
                            );
                          }
                        },
                      ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          if (context.read<EpgBloc>().state.currentPage !=
                              index) {
                            context.read<EpgBloc>().add(EpgPageChanged(index));
                          }
                        },
                        itemCount: _pageCount,
                        itemBuilder: (context, pageIndex) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: _EpgPageContent(
                              pageIndex: pageIndex,
                              state: state,
                              columnFocusNodes: _columnFocusNodes,
                              onChannelLaunch: widget.onChannelLaunch,
                              onScrollUpChanged:
                                  (can) => _canScrollUp.value = can,
                              onScrollDownChanged:
                                  (can) => _canScrollDown.value = can,
                            ),
                          );
                        },
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _canScrollUp,
                      builder: (context, canScrollUp, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _canScrollDown,
                          builder: (context, canScrollDown, _) {
                            return NavigationHints(
                              showVertical: canScrollUp || canScrollDown,
                              canScrollUp: canScrollUp,
                              canScrollDown: canScrollDown,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EpgPageContent extends StatelessWidget {
  final int pageIndex;
  final EpgState state;
  final List<FocusNode> columnFocusNodes;
  final ValueChanged<EpgChannel> onChannelLaunch;
  final ValueChanged<bool> onScrollUpChanged;
  final ValueChanged<bool> onScrollDownChanged;

  const _EpgPageContent({
    required this.pageIndex,
    required this.state,
    required this.columnFocusNodes,
    required this.onChannelLaunch,
    required this.onScrollUpChanged,
    required this.onScrollDownChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFocus = state.currentPage == pageIndex;

    switch (pageIndex) {
      case 0:
        return ChannelsListView(
          focusNode: columnFocusNodes[0],
          hasFocus: hasFocus,
          onChannelLaunch: onChannelLaunch,
          onScrollUpChanged: onScrollUpChanged,
          onScrollDownChanged: onScrollDownChanged,
        );
      case 1:
        return ProgramsListView(
          focusNode: columnFocusNodes[1],
          hasFocus: hasFocus,
          onScrollUpChanged: onScrollUpChanged,
          onScrollDownChanged: onScrollDownChanged,
        );
      case 2:
        return ProgramDetailsView(
          focusNode: columnFocusNodes[2],
          hasFocus: hasFocus,
          onScrollUpChanged: onScrollUpChanged,
          onScrollDownChanged: onScrollDownChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
