import 'package:flutter/material.dart';

/// DEPRECATED: Localization support has been removed.
/// This file is kept for reference but is no longer used.
class LocaleProvider extends ChangeNotifier {
  final Locale _locale = const Locale('en');

  Locale get locale => _locale;

  LocaleProvider() {
    // Localization disabled - keeping only default English
  }
}
