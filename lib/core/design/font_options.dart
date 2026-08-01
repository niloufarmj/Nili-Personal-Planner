import 'package:flutter/material.dart';

/// A selectable app-wide font pairing.
///
/// [headlineFamily]/[bodyFamily] are Google Fonts family names (case
/// sensitive) resolved via `GoogleFonts.getFont`. [emphasisWeight] is the
/// weight used for headings/titles/labels — it's chosen per family to match
/// a weight that's actually bundled offline for it (see
/// assets/google_fonts/), since `GoogleFonts.config.allowRuntimeFetching` is
/// disabled and an unbundled weight would fail to load.
enum AppFontOption {
  classic(
    id: 'classic',
    label: 'Classic',
    previewText: 'Aa',
    headlineFamily: 'Fraunces',
    bodyFamily: 'Nunito Sans',
    emphasisWeight: FontWeight.w600,
  ),
  comicNeue(
    id: 'comic_neue',
    label: 'Comic',
    previewText: 'Aa',
    headlineFamily: 'Comic Neue',
    bodyFamily: 'Comic Neue',
    emphasisWeight: FontWeight.w700,
  ),
  tinos(
    id: 'tinos',
    label: 'Times Classic',
    previewText: 'Aa',
    headlineFamily: 'Tinos',
    bodyFamily: 'Tinos',
    emphasisWeight: FontWeight.w700,
  ),
  robotoMono(
    id: 'roboto_mono',
    label: 'Mono',
    previewText: 'Aa',
    headlineFamily: 'Roboto Mono',
    bodyFamily: 'Roboto Mono',
    emphasisWeight: FontWeight.w500,
  ),
  fredoka(
    id: 'fredoka',
    label: 'Fredoka',
    previewText: 'Aa',
    headlineFamily: 'Fredoka',
    bodyFamily: 'Fredoka',
    emphasisWeight: FontWeight.w600,
  );

  const AppFontOption({
    required this.id,
    required this.label,
    required this.previewText,
    required this.headlineFamily,
    required this.bodyFamily,
    required this.emphasisWeight,
  });

  final String id;
  final String label;
  final String previewText;
  final String headlineFamily;
  final String bodyFamily;
  final FontWeight emphasisWeight;

  static AppFontOption fromId(String? id) =>
      values.firstWhere((f) => f.id == id, orElse: () => classic);
}
