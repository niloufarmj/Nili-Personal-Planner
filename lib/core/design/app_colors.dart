import 'package:flutter/material.dart';
import 'tokens.dart';

/// Central color palette for the Personal Planner app, deriving values from [DesignTokens].
abstract final class AppColors {
  // ── Location overlays ──────────────────────────────────────────
  static const Color linz = DesignTokens.butter;
  static const Color salzburg = DesignTokens.lavender;
  static const Color travel = DesignTokens.sage;

  // ── Priority ───────────────────────────────────────────────────
  static const Color priorityHigh = DesignTokens.accentLight;
  static const Color priorityNormal = DesignTokens.dustyBlue;
  static const Color priorityLow = DesignTokens.inkSoftLight;

  // ── Category palette (event types, collections) ────────────────
  static const Color catSocial = DesignTokens.rose;
  static const Color catAppointment = DesignTokens.blush;
  static const Color catPartner = DesignTokens.dustyBlueSoft;
  static const Color catUni = DesignTokens.sage;
  static const Color catWork = DesignTokens.lavender;
  static const Color catFinance = DesignTokens.sage;
  static const Color catFitness = DesignTokens.dustyBlue;
  static const Color catMeals = DesignTokens.peach;
  static const Color catHabits = DesignTokens.dustyBlue;

  // ── Surface / neutral ──────────────────────────────────────────
  static const Color surface = DesignTokens.paperLight;
  static const Color surfaceDark = DesignTokens.paperDark;
  static const Color cardLight = DesignTokens.surfaceLight;
  static const Color cardDark = DesignTokens.surfaceDark;
  static const Color divider = DesignTokens.lineLight;
  static const Color dividerDark = DesignTokens.lineDark;

  // ── Status chips ───────────────────────────────────────────────
  static const Color statusOpen = DesignTokens.lineLight;
  static const Color statusDone = DesignTokens.success;
  static const Color statusBlocked = DesignTokens.danger;
  static const Color statusPlanned = DesignTokens.dustyBlueSoft;

  // ── Custom semantic helpers ────────────────────────────────────
  static const Color success = DesignTokens.success;
  static const Color warning = DesignTokens.warning;
  static const Color danger = DesignTokens.danger;

  /// Returns the canonical color for a tag kind/name combination.
  static Color forTagName(String name) => switch (name.toLowerCase()) {
    'linz' => linz,
    'salzburg' => salzburg,
    'travel' => travel,
    'gym' => catFitness,
    'work' => catWork,
    _ => catSocial,
  };

  static Color forPriority(int priority) => switch (priority) {
    1 => priorityHigh,
    3 => priorityLow,
    _ => priorityNormal,
  };
}

