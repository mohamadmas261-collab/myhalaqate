import 'package:flutter/material.dart';

final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);