import 'package:flutter/material.dart';

/// Central color palette for the Personal Planner app.
abstract final class AppColors {
  // ── Location overlays ──────────────────────────────────────────
  static const Color linz = Color(0xFFF5C518);
  static const Color salzburg = Color(0xFF7C5CBF);
  static const Color travel = Color(0xFF3EBF6F);

  // ── Priority ───────────────────────────────────────────────────
  static const Color priorityHigh = Color(0xFFE53935);
  static const Color priorityNormal = Color(0xFF1E88E5);
  static const Color priorityLow = Color(0xFF757575);

  // ── Category palette (event types, collections) ────────────────
  static const Color catSocial = Color(0xFFFF7043);
  static const Color catAppointment = Color(0xFF00ACC1);
  static const Color catPartner = Color(0xFFAB47BC);
  static const Color catUni = Color(0xFF43A047);
  static const Color catWork = Color(0xFF1565C0);
  static const Color catFinance = Color(0xFF00897B);
  static const Color catFitness = Color(0xFFEF6C00);
  static const Color catMeals = Color(0xFF6D4C41);
  static const Color catHabits = Color(0xFF0288D1);

  // ── Surface / neutral ──────────────────────────────────────────
  static const Color surface = Color(0xFFFAFAFA);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF2C2C2C);

  // ── Status chips ───────────────────────────────────────────────
  static const Color statusOpen = Color(0xFFE0E0E0);
  static const Color statusDone = Color(0xFFC8E6C9);
  static const Color statusBlocked = Color(0xFFFFCDD2);
  static const Color statusPlanned = Color(0xFFBBDEFB);

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
