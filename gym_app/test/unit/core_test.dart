import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/errors/exceptions.dart';
import 'package:gym_app/core/errors/failures.dart';
import 'package:gym_app/core/config/app_constants.dart';

void main() {
  group('AuthException.fromFirebaseCode', () {
    test('mapeia user-not-found', () {
      final ex = AuthException.fromFirebaseCode('user-not-found');
      expect(ex.code, 'user-not-found');
      expect(ex.message, contains('não encontrado'));
    });

    test('mapeia wrong-password', () {
      final ex = AuthException.fromFirebaseCode('wrong-password');
      expect(ex.code, 'wrong-password');
      expect(ex.message, contains('incorreta'));
    });

    test('mapeia email-already-in-use', () {
      final ex = AuthException.fromFirebaseCode('email-already-in-use');
      expect(ex.code, 'email-already-in-use');
      expect(ex.message, contains('já está registado'));
    });

    test('mapeia invalid-email', () {
      final ex = AuthException.fromFirebaseCode('invalid-email');
      expect(ex.code, 'invalid-email');
      expect(ex.message, contains('inválido'));
    });

    test('mapeia user-disabled', () {
      final ex = AuthException.fromFirebaseCode('user-disabled');
      expect(ex.code, 'user-disabled');
      expect(ex.message, contains('desativada'));
    });

    test('mapeia weak-password', () {
      final ex = AuthException.fromFirebaseCode('weak-password');
      expect(ex.code, 'weak-password');
      expect(ex.message, contains('fraca'));
    });

    test('mapeia network-request-failed', () {
      final ex = AuthException.fromFirebaseCode('network-request-failed');
      expect(ex.code, 'network-request-failed');
      expect(ex.message, contains('internet'));
    });

    test('mapeia too-many-requests', () {
      final ex = AuthException.fromFirebaseCode('too-many-requests');
      expect(ex.code, 'too-many-requests');
      expect(ex.message, contains('Demasiadas tentativas'));
    });

    test('código desconhecido usa mensagem padrão', () {
      final ex = AuthException.fromFirebaseCode('unknown-error-xyz');
      expect(ex.code, 'unknown-error-xyz');
      expect(ex.message, contains('Ocorreu um erro'));
    });
  });

  group('Exceptions', () {
    test('ServerException tem valores padrão', () {
      const ex = ServerException();
      expect(ex.message, 'Erro no servidor');
      expect(ex.statusCode, isNull);
    });

    test('CacheException tem valores padrão', () {
      const ex = CacheException();
      expect(ex.message, 'Erro de cache');
    });

    test('NetworkException tem valores padrão', () {
      const ex = NetworkException();
      expect(ex.message, 'Sem ligação à internet');
    });

    test('PermissionException tem valores padrão', () {
      const ex = PermissionException();
      expect(ex.message, 'Permissão negada');
    });

    test('DocumentNotFoundException tem valores padrão', () {
      const ex = DocumentNotFoundException();
      expect(ex.message, 'Documento não encontrado');
    });

    test('ValidationException requer mensagem', () {
      const ex = ValidationException(message: 'Campo obrigatório', field: 'nome');
      expect(ex.message, 'Campo obrigatório');
      expect(ex.field, 'nome');
    });
  });

  group('Failures (Equatable)', () {
    test('ServerFailure tem props corretos', () {
      const f = ServerFailure(message: 'Erro', statusCode: 500);
      expect(f.props, ['Erro']);
      expect(f.statusCode, 500);
    });

    test('AuthFailure inclui code nos props', () {
      const f = AuthFailure(message: 'Erro', code: 'auth-123');
      expect(f.props, ['Erro', 'auth-123']);
    });

    test('ValidationFailure inclui field nos props', () {
      const f = ValidationFailure(message: 'Erro', field: 'email');
      expect(f.props, ['Erro', 'email']);
    });

    test('Failures são Equatable - iguais com mesmos valores', () {
      const a = ServerFailure(message: 'Erro');
      const b = ServerFailure(message: 'Erro');
      expect(a, equals(b));
    });

    test('Failures são Equatable - diferentes com valores diferentes', () {
      const a = ServerFailure(message: 'Erro');
      const b = ServerFailure(message: 'Outro erro');
      expect(a, isNot(equals(b)));
    });

    test('CacheFailure usa mensagem padrão', () {
      const f = CacheFailure();
      expect(f.message, 'Erro de cache');
    });

    test('NetworkFailure usa mensagem padrão', () {
      const f = NetworkFailure();
      expect(f.message, 'Sem ligação à internet');
    });

    test('PermissionFailure usa mensagem padrão', () {
      const f = PermissionFailure();
      expect(f.message, 'Permissão negada');
    });

    test('DocumentNotFoundFailure usa mensagem padrão', () {
      const f = DocumentNotFoundFailure();
      expect(f.message, 'Documento não encontrado');
    });
  });

  group('AppConstants', () {
    test('dailyWaterGoalMl é 2500', () {
      expect(AppConstants.dailyWaterGoalMl, 2500);
    });

    test('waterIncrementMl é 250', () {
      expect(AppConstants.waterIncrementMl, 250);
    });

    test('dailyStepsGoal é 10000', () {
      expect(AppConstants.dailyStepsGoal, 10000);
    });

    test('minRating e maxRating', () {
      expect(AppConstants.minRating, 1);
      expect(AppConstants.maxRating, 5);
    });

    test('imageQuality e dimensões', () {
      expect(AppConstants.imageQuality, 70);
      expect(AppConstants.maxImageWidth, 1024);
      expect(AppConstants.maxImageHeight, 1024);
    });

    test('maxMessageLength é 1000', () {
      expect(AppConstants.maxMessageLength, 1000);
    });

    test('defaultPageSize é 20', () {
      expect(AppConstants.defaultPageSize, 20);
    });

    test('formats de data', () {
      expect(AppConstants.dateFormat, 'yyyy-MM-dd');
      expect(AppConstants.displayDateFormat, 'dd/MM/yyyy');
      expect(AppConstants.displayDateTimeFormat, 'dd/MM/yyyy HH:mm');
    });

    test('collections do Firestore', () {
      expect(AppConstants.usersCollection, 'users');
      expect(AppConstants.diarySubcollection, 'diario');
      expect(AppConstants.foodsCollection, 'alimentos');
      expect(AppConstants.exercisesCollection, 'exercicios');
      expect(AppConstants.chatCollection, 'chat');
    });

    test('roles', () {
      expect(AppConstants.roleAluno, 'aluno');
      expect(AppConstants.roleAdmin, 'admin');
    });

    test('chatRoomPrefix', () {
      expect(AppConstants.chatRoomPrefix, 'chat');
    });

    test('bmiCategories tem 6 categorias', () {
      expect(AppConstants.bmiCategories.length, 6);
      expect(AppConstants.bmiCategories.containsKey('Abaixo do peso'), true);
      expect(AppConstants.bmiCategories.containsKey('Peso normal'), true);
      expect(AppConstants.bmiCategories.containsKey('Sobrepeso'), true);
      expect(AppConstants.bmiCategories.containsKey('Obesidade Grau I'), true);
      expect(AppConstants.bmiCategories.containsKey('Obesidade Grau II'), true);
      expect(AppConstants.bmiCategories.containsKey('Obesidade Grau III'), true);
    });

    test('storage paths', () {
      expect(AppConstants.profilePhotoPath, contains('profile.jpg'));
      expect(AppConstants.progressPhotoPath, contains('progresso'));
      expect(AppConstants.exerciseVideoPath, contains('video.mp4'));
    });
  });
}
