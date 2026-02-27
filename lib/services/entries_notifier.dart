import 'package:flutter/foundation.dart';

class EntriesNotifier extends ChangeNotifier {
  EntriesNotifier._internal();
  static final EntriesNotifier _instance = EntriesNotifier._internal();
  factory EntriesNotifier() => _instance;

  void notifyEntryAdded() {
    notifyListeners();
  }
}

