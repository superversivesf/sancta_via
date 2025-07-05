import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import '../providers/theme_providers.dart';
import '../extensions/liturgical_color_extensions.dart';
import '../extensions/theme_extensions.dart';

class LiturgicalColorPreview extends ConsumerWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final VoidCallback? onTap;

  const LiturgicalColorPreview({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: leading ?? const Icon(Icons.color_lens),
      title: Text(title ?? 'Preview Liturgical Colors'),
      subtitle: Text(subtitle ?? 'See how the app looks in different liturgical seasons'),
      onTap: onTap ?? () {
        _showColorPreview(context, ref);
      },
    );
  }

  void _showColorPreview(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Liturgical Color Preview',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildColorPreviewCard(context, ref, LiturgicalColor.green, 'Ordinary Time'),
                      _buildColorPreviewCard(context, ref, LiturgicalColor.purple, 'Advent & Lent'),
                      _buildColorPreviewCard(context, ref, LiturgicalColor.rose, 'Gaudete & Laetare Sundays'),
                      _buildColorPreviewCard(context, ref, LiturgicalColor.white, 'Christmas & Easter'),
                      _buildColorPreviewCard(context, ref, LiturgicalColor.red, 'Pentecost & Martyrs'),
                      _buildColorPreviewCard(context, ref, LiturgicalColor.gold, 'High Feasts'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorPreviewCard(BuildContext context, WidgetRef ref, LiturgicalColor liturgicalColor, String description) {
    final colorIntensity = ref.watch(colorIntensityProvider);
    final color = liturgicalColor.toFlutterColor(colorIntensity);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: 3,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          title: Text(
            liturgicalColor.displayName.toLowerCase().capitalize(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          subtitle: Text(description),
        ),
      ),
    );
  }
}