import 'package:flutter/material.dart';
import 'package:gallery/catalog/catalog.dart';
import 'package:gallery/catalog/example_section.dart';
import 'package:gallery/catalog/glyphs.dart';
import 'package:gallery/design/gallery_theme.dart';
import 'package:gallery/design/node_glyph.dart';
import 'package:gallery/features/detail/detail_screen.dart';
import 'package:gallery/app/gallery_locale.dart';
import 'package:gallery/features/hub/example_card.dart';
import 'package:gallery/l10n/gallery_l10n.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);
    final sections = buildSections(l10n);

    return Scaffold(
      body: Stack(
        children: [
          const _CornerGlow(),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                  sliver: SliverToBoxAdapter(child: _Masthead()),
                ),
                for (final group in sections) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(section: group.section),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.separated(
                      itemCount: group.entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => ExampleCard(
                        entry: group.entries[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DetailScreen(entry: group.entries[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A section heading: what this group is about, in one line.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final ExampleSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);
    final text = GalleryText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title(l10n).toUpperCase(), style: text.monoCaps),
        const SizedBox(height: 4),
        Text(section.blurb(l10n), style: text.cardBody),
      ],
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);
    final text = GalleryText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            NodeGlyphIcon(
              glyph: Glyphs.mark,
              color: GalleryColors.screen,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cobalt', style: text.wordmark),
                  Text(l10n.tagline, style: text.subtitle),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _LanguageSwitch(),
        const SizedBox(height: 18),
        Text(l10n.lede, style: text.lede),
      ],
    );
  }
}

/// The language chooser, offering each language written in itself.
///
/// What is selected comes from `Localizations.localeOf` rather than from a
/// field of our own: the app can be following the device, and then nobody has
/// chosen anything yet — but something is still in force, and that is what a
/// reader is looking at.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final active = Localizations.localeOf(context).languageCode;
    final select = GalleryLocaleScope.of(context).select;

    return Semantics(
      label: GalleryL10n.of(context).languageTooltip,
      // Scrolls sideways: four languages, and a fifth some day, do not all
      // fit a phone at once — Korean was the one that first ran past it.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final locale in GalleryLocaleScope.supported)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _LanguageChip(
                  code: locale.languageCode,
                  isActive: locale.languageCode == active,
                  onTap: () => select(locale),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.code,
    required this.isActive,
    required this.onTap,
  });

  final String code;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: isActive
        ? GalleryColors.screen.withValues(alpha: 0.16)
        : GalleryColors.card,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      key: Key('language-$code'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isActive ? GalleryColors.screen : GalleryColors.hairline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Text(
            GalleryLocaleScope.endonyms[code] ?? code,
            style: GalleryText.of(context).cardBody.copyWith(
              color: isActive ? GalleryColors.screen : GalleryColors.textMuted,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The soft light behind the masthead, so the top of the screen is not a flat
/// rectangle of one colour.
class _CornerGlow extends StatelessWidget {
  const _CornerGlow();

  @override
  Widget build(BuildContext context) => Positioned(
    top: -170,
    left: -90,
    child: IgnorePointer(
      child: Container(
        width: 440,
        height: 350,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              GalleryColors.screen.withValues(alpha: 0.15),
              GalleryColors.screen.withValues(alpha: 0),
            ],
            stops: const [0, 0.68],
          ),
        ),
      ),
    ),
  );
}
