import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

/// Finders for global search: the entry on Home and the screen it opens (#557).
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
class GlobalSearchScreenObject {
  const GlobalSearchScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// The search icon in Home's header.
  PatrolFinder get homeSearchButton => $(Icons.search_rounded);

  /// The search field in the app bar.
  PatrolFinder get field => $(TextField);

  /// A group's heading, whatever its count: `Classes (1)`.
  PatrolFinder group(String name) => $(RegExp('^$name \\('));
}
