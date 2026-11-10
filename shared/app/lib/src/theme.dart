import 'package:flutter/material.dart';

/// The app's one theme. Domain packages use Theme.of(context), never their own colours.
ThemeData tsrTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
      useMaterial3: true,
    );
