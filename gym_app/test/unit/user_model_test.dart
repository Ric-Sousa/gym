import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    const uid = 'user123';
    const nome = 'João Silva';
    const email = 'joao@email.com';

    test('fromMap cria modelo com todos os campos', () {
      final map = {
        'nome': nome,
        'email': email,
        'role': 'aluno',
        'pesoAtual': 80.5,
        'altura': 175.0,
        'fotoPerfil': 'https://example.com/photo.jpg',
        'personalId': 'trainer1',
      };

      final user = UserModel.fromMap(uid, map);

      expect(user.uid, uid);
      expect(user.nome, nome);
      expect(user.email, email);
      expect(user.role, 'aluno');
      expect(user.pesoAtual, 80.5);
      expect(user.altura, 175.0);
      expect(user.fotoPerfil, 'https://example.com/photo.jpg');
      expect(user.personalId, 'trainer1');
    });

    test('fromMap usa valores padrão quando campos estão ausentes', () {
      final map = <String, dynamic>{};

      final user = UserModel.fromMap(uid, map);

      expect(user.nome, '');
      expect(user.email, '');
      expect(user.role, 'aluno');
      expect(user.pesoAtual, isNull);
      expect(user.altura, isNull);
      expect(user.fotoPerfil, isNull);
      expect(user.isAluno, true);
      expect(user.isAdmin, false);
    });

    test('toMap converte para mapa corretamente', () {
      final user = UserModel(
        uid: uid,
        nome: nome,
        email: email,
        pesoAtual: 80.5,
        altura: 175.0,
      );

      final map = user.toMap();

      expect(map['nome'], nome);
      expect(map['email'], email);
      expect(map['role'], 'aluno');
      expect(map['pesoAtual'], 80.5);
      expect(map['altura'], 175.0);
      expect(map.containsKey('fotoPerfil'), false);
    });

    test('copyWith altera apenas campos especificados', () {
      final user = UserModel(uid: uid, nome: nome, email: email);

      final updated = user.copyWith(pesoAtual: 80.0);

      expect(updated.uid, uid);
      expect(updated.nome, nome);
      expect(updated.pesoAtual, 80.0);
    });

    test('imc calcula corretamente', () {
      final user = UserModel(
        uid: uid,
        nome: nome,
        email: email,
        pesoAtual: 80.0,
        altura: 175.0,
      );

      // 80 / (1.75 * 1.75) ≈ 26.12
      expect(user.imc, closeTo(26.12, 0.1));
      expect(user.imcCategory, 'Sobrepeso');
    });

    test('imc é null quando peso ou altura ausentes', () {
      final user = UserModel(uid: uid, nome: nome, email: email);

      expect(user.imc, isNull);
      expect(user.imcCategory, isNull);
    });
  });
}
