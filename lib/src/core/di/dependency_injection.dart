import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../base/crash_reporter.dart';
import '../../data/repositories/locale_repository_impl.dart';
import '../../data/services/cache/cache_service.dart';
import '../../data/services/cache/shared_preferences_service.dart';
import '../../domain/repositories/locale_repository.dart';
import '../../domain/use_cases/locale_use_case.dart';
import '../../domain/use_cases/reset_repository_use_case.dart';

part 'dependency_injection.g.dart';
part 'parts/externals.dart';
part 'parts/repository.dart';
part 'parts/services.dart';
part 'parts/use_cases.dart';
