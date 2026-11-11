import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';

import 'saint_image.dart';

/// A list-row card for a saint: thumb, name, and the first patronage.
///
/// The whole card is tappable and navigates to `/saints/<slug>`. Rendered
/// with the house list-row pattern (`Card` > `InkWell`); consumers pass
/// `key: Key('saint_card_<slug>')` so screens can target specific cards.
class SaintCard extends StatelessWidget {
  const SaintCard({required this.saint, super.key});

  /// The saint to render.
  final Saint saint;

  @override
  Widget build(BuildContext context) {
    final SaintPatronage? firstPatronage = saint.patronages.isNotEmpty
        ? saint.patronages.first
        : null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/saints/${saint.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              SaintImage(
                saint: saint,
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      saint.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (firstPatronage != null)
                      Text(
                        '${firstPatronage.need} · '
                        '${firstPatronage.category.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
