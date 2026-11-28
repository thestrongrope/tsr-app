import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import '../services/wordpress_service.dart';
import '../repositories/wordpress_repository.dart';
import '../../../core/constants/app_constants.dart';

final wpRepositoryProvider = Provider<WordPressRepository>((ref) {
  final svc = WordPressService();
  final box = Hive.box(AppConstants.cacheBoxKey);
  return WordPressRepository(svc, box);
});
