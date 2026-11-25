import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'campaign.dart';
import 'colony_screen.dart';
import 'creatures.dart';
import 'creature_view.dart';
import 'hum.dart';
import 'library.dart';
import 'local_store.dart';
import 'updates.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
  }
  runApp(const Sodukromental());
}

ThemeData gameTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Hum.focus,
    primary: Hum.focus,
    onPrimary: Hum.board,
    secondary: Hum.pearEdge,
    surface: Hum.paper,
    onSurface: Hum.ink,
    error: Hum.error,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: Hum.headingFont,
    colorScheme: scheme,
    scaffoldBackgroundColor: Hum.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Hum.paper,
      foregroundColor: Hum.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Hum.paper,
      indicatorColor: Hum.cyan,
      height: 64,
    ),
    dividerColor: Hum.grid.withValues(alpha: .25),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}

class Sodukromental extends StatefulWidget {
  const Sodukromental({super.key});
  @override
  State<Sodukromental> createState() => _SodukromentalState();
}

class _SodukromentalState extends State<Sodukromental> {
  late final LocalStore db = LocalStore.open();
  late Future<GameSession> load = _load();
  Future<GameSession> _load() async {
    final persisted = await db.read('campaign');
    final prefs = await db.read('settings') ?? <String, dynamic>{};
    final run = persisted == null
        ? Campaign(seed: Random.secure().nextInt(0x7fffffff))
        : Campaign.fromJson(persisted);
    final package = await PackageInfo.fromPlatform();
    final httpClient = http.Client();
    return GameSession(
      run,
      prefs,
      package,
      httpClient,
      UpdateService(
        version: package.version,
        code: int.tryParse(package.buildNumber) ?? 0,
        packageId: package.packageName,
        client: httpClient,
        save: (v) => db.put('update', v),
        cached: await db.read('update'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sodukromental',
    debugShowCheckedModeBanner: false,
    theme: gameTheme(),
    home: FutureBuilder<GameSession>(
      future: load,
      builder: (context, snapshot) {
        if (snapshot.data case final player?) {
          return GameHome(player: player, db: db);
        }
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Your local save could not be opened.'),
                        TextButton(
                          onPressed: () => setState(() => load = _load()),
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(
                      semanticsLabel: 'Opening your colony',
                    ),
            ),
          ),
        );
      },
    ),
  );
}

class GameSession {
  GameSession(
    this.run,
    this.settings,
    this.package,
    this.transport,
    this.updates,
  );
  final Campaign run;
  final Map<String, dynamic> settings;
  final PackageInfo package;
  final http.Client transport;
  final UpdateService updates;
}

class GameHome extends StatefulWidget {
  const GameHome({
    super.key,
    required this.player,
    required this.db,
    this.openLibrary = LibraryStore.open,
    this.syncLibrary = true,
  });
  final Future<LibraryStore> Function() openLibrary;
  final bool syncLibrary;
  final GameSession player;
  final LocalStore db;
  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> with WidgetsBindingObserver {
  GameSession get player => widget.player;
  Campaign get run => player.run;
  late final Timer timer;
  late Future<LibraryStore> library = widget.openLibrary();
  late int tab = player.settings['destination'] == 'sudoku' ? 1 : 0;
  bool foreground = true, dirty = false, saving = false;
  bool saveFailed = false, invited = false, calledBack = false;
  bool get motion =>
      player.settings['reduceMotion'] == true ||
      MediaQuery.disableAnimationsOf(context);
  bool get tilt => player.settings['tilt'] != false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    run.onChanged = _changed;
    run.tick(DateTime.now(), offline: true);
    timer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (foreground) run.tick(DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _autoUpdate();
        // Begin indexing the offline library independently of the first board.
        library.ignore();
      }
    });
  }

  void _changed() {
    dirty = true;
    if (!saving) unawaited(_flush());
    if (mounted) setState(() {});
  }

  Future<void> _flush() async {
    if (saving) return;
    saving = true;
    try {
      while (dirty) {
        dirty = false;
        await widget.db.put('campaign', run.toJson());
      }
      if (saveFailed && mounted) setState(() => saveFailed = false);
    } catch (_) {
      dirty = true;
      if (mounted) setState(() => saveFailed = true);
    } finally {
      saving = false;
    }
  }

  Future<void> _preferences() => widget.db.put('settings', player.settings);
  Future<void> _autoUpdate() async {
    if (!Platform.isAndroid ||
        !const bool.fromEnvironment('GITHUB_DISTRIBUTION'))
      return;
    await player.updates.check();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !foreground) {
      foreground = true;
      run.tick(DateTime.now(), offline: true);
      unawaited(_autoUpdate());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      foreground = false;
      dirty = true;
      unawaited(_flush());
    }
  }

  @override
  void dispose() {
    timer.cancel();
    player.transport.close();
    library.then((value) => value.close()).ignore();
    run.onChanged = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _destination(int value) {
    setState(() {
      tab = value;
      invited = calledBack = false;
      player.settings['destination'] = value == 0 ? 'colony' : 'sudoku';
    });
    unawaited(_preferences());
  }

  void _creator([CreatureRecipe? initial]) async {
    final helper = await Navigator.of(context).push<Creature>(
      MaterialPageRoute(
        builder: (_) => CreatureCreatorScreen(
          milestone: run.growthMilestone,
          quote: run.hatchPrice,
          onHatch: (id, recipe, price) => run.hatch(id, recipe, quote: price),
          dna: run.dna,
          rna: run.rna,
          occupied: run.creatures
              .where((c) => c.isAmoeba || !c.memory.retained)
              .length,
          housing: run.housing,
          oneHelper: run.charter == Charter.oneHelper,
          reducedMotion: motion,
          initialRecipe: initial,
        ),
      ),
    );
    if (helper != null && mounted) _profile(helper);
  }

  void _profile(Creature helper) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatureProfileScreen(
          creature: helper,
          selectedToKeep: run.companionChoice == helper.id,
          suggestedDigit: helper.memory.suggestDigit(run.tray),
          onKeep: (keep) => run.keepCompanion(keep ? helper.id : null),
          onChanged: _changed,
          reducedMotion: motion,
          onEncourage: () => run.encourage(helper.id),
          onEditRecipe: helper.isAmoeba
              ? null
              : () {
                  Navigator.of(context).pop();
                  _creator(helper.recipe);
                },
        ),
      ),
    );
  }

  void _settings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _Settings(
          player: player,
          library: library,
          settingsChanged: () {
            setState(() {});
            unawaited(_preferences());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = run.companion;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
          child: Image.asset(
            'assets/brand/mark.png',
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
        ),
        titleSpacing: 8,
        title: const Text(
          'Sodukromental',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
        ),
        actions: [
          if (pet != null && pet.memory.retained)
            IconButton(
              tooltip: 'Invite ${pet.name} here',
              onPressed: () => setState(() {
                invited = true;
                calledBack = false;
              }),
              icon: const Icon(Icons.pets_outlined),
            ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _settings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            if (saveFailed)
              ListTile(
                title: const Text('Changes are waiting to be saved.'),
                trailing: TextButton(
                  onPressed: _flush,
                  child: const Text('Retry'),
                ),
              ),
            if (tab == 1 && player.updates.showBanner)
              ListTile(
                title: Text(
                  'Update available · ${player.updates.available!.version}',
                ),
                onTap: () => launchUrl(
                  player.updates.available!.page,
                  mode: LaunchMode.externalApplication,
                ),
                trailing: IconButton(
                  tooltip: 'Dismiss update',
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await player.updates.dismiss();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            if (pet != null && pet.memory.retained && !calledBack)
              CompanionVisit(
                creature: pet,
                waypoint: tab == 0
                    ? CompanionWaypoint.home
                    : CompanionWaypoint.library,
                onCallBack: () => setState(() {
                  calledBack = true;
                  invited = false;
                }),
                onChanged: _changed,
                priorityWork: run.jobs.any((j) => j.workerId == pet.id),
                reducedMotion: motion,
                invited: invited,
              ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  TickerMode(
                    enabled: tab == 0,
                    child: ColonyScreen(
                      campaign: run,
                      onChanged: () {},
                      onOpenSettings: _settings,
                      onOpenCreator: _creator,
                      onOpenProfile: _profile,
                      reducedMotion: motion,
                      tiltEnabled: tilt && tab == 0,
                    ),
                  ),
                  FutureBuilder<LibraryStore>(
                    future: library,
                    builder: (context, snapshot) {
                      if (snapshot.data case final store?) {
                        return LibraryScreen(
                          store: store,
                          active: tab == 1,
                          startSync: widget.syncLibrary,
                          canColonyPlay: (b) => run.canOpenLibrarySize(b.size),
                          onColonyPlay: (b) {
                            if (run.openLibraryChallenge(b)) _destination(0);
                          },
                        );
                      }
                      if (snapshot.hasError)
                        return Center(
                          child: TextButton(
                            onPressed: () =>
                                setState(() => library = widget.openLibrary()),
                            child: const Text('Retry opening the Library'),
                          ),
                        );
                      return const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Preparing the Library',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: _destination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grass_outlined),
            selectedIcon: Icon(Icons.grass),
            label: 'Colony',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Sudoku',
          ),
        ],
      ),
    );
  }
}

class _Settings extends StatefulWidget {
  const _Settings({
    required this.player,
    required this.library,
    required this.settingsChanged,
  });
  final GameSession player;
  final Future<LibraryStore> library;
  final VoidCallback settingsChanged;
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  String? updateMessage;
  bool checking = false;
  void pref(String name, bool value) {
    widget.player.settings[name] = value;
    widget.settingsChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Label('Sudoku Library'),
          FutureBuilder<LibraryStore>(
            future: widget.library,
            builder: (_, snapshot) => snapshot.data == null
                ? const ListTile(title: Text('Opening library settings…'))
                : LibrarySettingsTile(store: snapshot.requireData),
          ),
          const _Label('Play'),
          SwitchListTile(
            title: const Text('Tilt gravity'),
            subtitle: const Text('Directional buttons are always available.'),
            value: p.settings['tilt'] != false,
            onChanged: (v) => pref('tilt', v),
          ),
          SwitchListTile(
            title: const Text('Reduce motion'),
            subtitle: const Text(
              'Show completed steps without travel animations.',
            ),
            value: p.settings['reduceMotion'] == true,
            onChanged: (v) => pref('reduceMotion', v),
          ),
          ListTile(
            title: const Text('Creature antics'),
            trailing: DropdownButton<Antics>(
              value: p.run.antics,
              items: const [
                DropdownMenuItem(
                  value: Antics.full,
                  child: Text('Full antics'),
                ),
                DropdownMenuItem(
                  value: Antics.reactions,
                  child: Text('Reactions only'),
                ),
                DropdownMenuItem(value: Antics.off, child: Text('Off')),
              ],
              onChanged: (value) {
                if (value != null) {
                  p.run.setAntics(value);
                  setState(() {});
                }
              },
            ),
          ),
          const _Label('App updates'),
          ListTile(
            title: const Text('Check for updates'),
            subtitle: Text(
              updateMessage ??
                  'Installed ${p.package.version} (${p.package.buildNumber})',
            ),
            onTap: checking
                ? null
                : () async {
                    setState(() => checking = true);
                    final message = await p.updates.check(manual: true);
                    if (mounted)
                      setState(() {
                        updateMessage = message;
                        checking = false;
                      });
                  },
            trailing: checking
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          if (p.updates.available case final update?)
            ListTile(
              title: Text('View release ${update.version}'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () =>
                  launchUrl(update.page, mode: LaunchMode.externalApplication),
            ),
          const _Label('Credits'),
          ListTile(
            title: const Text('Logic Masters Deutschland'),
            subtitle: const Text(
              'Community puzzles retain their author credits and original puzzle links.',
            ),
            onTap: () => launchUrl(
              Uri.https('logic-masters.de', '/Raetselportal/'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Sodukromental',
              applicationVersion: p.package.version,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Hum.focus,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
