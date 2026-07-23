import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/connectivity_service.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/datasources/firestore_datasource.dart';
import '../../data/datasources/storage_datasource.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/workout_repository.dart';

// ──────────── SERVICES ────────────

/// Provider para ConnectivityService (singleton).
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream de estado de conectividade.
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

// ──────────── DATASOURCES ────────────

final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  return AuthDataSource();
});

final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSource();
});

final storageDataSourceProvider = Provider<StorageDataSource>((ref) {
  return StorageDataSource();
});

// ──────────── REPOSITORIES ────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    authDataSource: ref.watch(authDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(
    firestoreDataSource: ref.watch(firestoreDataSourceProvider),
    storageDataSource: ref.watch(storageDataSourceProvider),
  );
});
