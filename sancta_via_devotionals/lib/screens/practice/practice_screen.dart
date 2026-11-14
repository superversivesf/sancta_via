// The Practice screen (Plan 2, Task 14): the app's discovery tab.
//
// Renders the WHOLE catalog — every pack the store carries, enrolled or not
// (the catalog is the discovery surface; the Task 5/6 "enrolled" ruling
// never filters it) — grouped by the engine's [PackFamily] in the enum's
// declaration order (commitment | novena | office | routine | chaplet).
// Families with no shipped packs (office) render no group header at all,
// mirroring Today's non-empty-sections rule.
//
// Each family group reuses [TodaySectionCard] (Task 13's presentation
// card); its tiles route to the program detail (`/program/:packId`), pushed
// over the shell so the stack keeps the Today/policy shape Task 13 pinned.
// The catalog reads [contentLoadedProvider] — the seeding-first-launch
// migration runs once through it — so the tab is self-sufficient on a fresh
// install exactly like Today.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show ContentPack, PackFamily;

import '../../providers/content_providers.dart';
import '../../utils/logger.dart';
import '../../widgets/today/today_section_card.dart';

/// The display title of a [PackFamily] group header.
String _familyTitle(PackFamily family) => switch (family) {
  PackFamily.commitment => 'Commitments',
  PackFamily.novena => 'Novenas',
  PackFamily.office => 'Office',
  PackFamily.routine => 'Routines',
  PackFamily.chaplet => 'Chaplets',
};

/// The group icon of a [PackFamily] — the same family→icon map the Today
/// tile use (an exhaustive switch over the engine's enum).
IconData _familyIcon(PackFamily family) => switch (family) {
  PackFamily.commitment => Icons.flag,
  PackFamily.novena => Icons.event_repeat,
  PackFamily.office => Icons.menu_book,
  PackFamily.routine => Icons.schedule,
  PackFamily.chaplet => Icons.blur_circular,
};

/// The app's Practice screen: the devotional catalog grouped by family.
class PracticeScreen extends ConsumerWidget {
  /// Creates the Practice screen.
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ContentPack>> catalog = ref.watch(
      contentLoadedProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) {
          AppLogger.error('Practice catalog failed', error, stack, 'PRACTICE');
          return const Center(
            child: Text(
              'The devotional catalog could not be loaded. '
              'Try reopening the app.',
              textAlign: TextAlign.center,
            ),
          );
        },
        data: (List<ContentPack> packs) => _CatalogList(packs: packs),
      ),
    );
  }
}

/// The catalog body for a seeded store: one non-empty group card per
/// [PackFamily] (enum order), each carrying its packs in the store's id
/// order — the ordering Task 5 pinned for catalog surfaces.
class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.packs});

  final List<ContentPack> packs;

  @override
  Widget build(BuildContext context) {
    final List<Widget> sections = <Widget>[
      for (final PackFamily family in PackFamily.values)
        if (packs.any((ContentPack pack) => pack.family == family))
          TodaySectionCard(
            title: _familyTitle(family),
            icon: Icon(_familyIcon(family)),
            children: <Widget>[
              for (final ContentPack pack in packs)
                if (pack.family == family) _CatalogTile(pack: pack),
            ],
          ),
    ];
    return ListView(children: sections);
  }
}

/// One catalog tile: the pack's title with its family icon; a tap pushes
/// the program detail route.
class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.pack});

  final ContentPack pack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      key: ValueKey<String>('catalog_item_${pack.id}'),
      leading: Icon(_familyIcon(pack.family), color: theme.colorScheme.primary),
      title: Text(pack.title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/program/${pack.id}'),
    );
  }
}
