import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'font_options.dart';

class FontNotifier extends StateNotifier<AppFontOption> {
  FontNotifier() : super(AppFontOption.classic) {
    _loadFont();
  }

  static const _fontKey = 'app_font_option';

  Future<void> _loadFont() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppFontOption.fromId(prefs.getString(_fontKey));
  }

  Future<void> setFont(AppFontOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, option.id);
  }
}

final fontOptionProvider =
    StateNotifierProvider<FontNotifier, AppFontOption>((ref) {
      return FontNotifier();
    });
