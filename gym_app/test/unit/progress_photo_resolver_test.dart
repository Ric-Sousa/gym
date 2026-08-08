import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/utils/progress_photo_resolver.dart';

void main() {
  // Índices dos ângulos em progressAngleLabels.
  const frente = 0;
  const costas = 1;
  const lado1 = 2;
  const lado2 = 3;

  const front = 'https://example.com/frente.jpg';
  const side1 = 'https://example.com/lado1.jpg';
  const side2 = 'https://example.com/lado2.jpg';
  const back = 'https://example.com/costas.jpg';

  String? resolve(
    List<String> fotos,
    Map<String, String> mapa,
    int angleIndex,
  ) {
    return resolveProgressPhotoAt(
      fotos: fotos,
      fotosPorPosicao: mapa,
      angleIndex: angleIndex,
    );
  }

  group('normalizeProgressPositionKey', () {
    test('normaliza variações de escrita', () {
      expect(normalizeProgressPositionKey('Frente'), 'frente');
      expect(normalizeProgressPositionKey(' frente '), 'frente');
      expect(normalizeProgressPositionKey('Costas'), 'costas');
      expect(normalizeProgressPositionKey('Lado 1'), 'lado1');
      expect(normalizeProgressPositionKey('lado-1'), 'lado1');
      expect(normalizeProgressPositionKey('Lado_2'), 'lado2');
      expect(normalizeProgressPositionKey('Lado Esquerdo'), 'lado1');
      expect(normalizeProgressPositionKey('lado direito'), 'lado2');
      expect(normalizeProgressPositionKey('Posterior'), 'costas');
    });

    test('devolve vazio para posições desconhecidas', () {
      expect(normalizeProgressPositionKey(''), isEmpty);
      expect(normalizeProgressPositionKey('diagonal'), isEmpty);
    });
  });

  group('resolveProgressPhotoAt — mapa explícito (formato novo)', () {
    test('(c) 4 slots com mapa completo resolvem todos os ângulos', () {
      final fotos = [front, side1, side2, back];
      final mapa = {
        'Frente': front,
        'Lado 1': side1,
        'Lado 2': side2,
        'Costas': back,
      };

      expect(resolve(fotos, mapa, frente), front);
      expect(resolve(fotos, mapa, lado1), side1);
      expect(resolve(fotos, mapa, lado2), side2);
      expect(resolve(fotos, mapa, costas), back);
    });

    test('mapa com chaves não normalizadas também resolve', () {
      final fotos = <String>[];
      final mapa = {'frente': front, 'lado-1': side1, 'COSTAS': back};

      expect(resolve(fotos, mapa, frente), front);
      expect(resolve(fotos, mapa, lado1), side1);
      expect(resolve(fotos, mapa, costas), back);
      expect(resolve(fotos, mapa, lado2), isNull);
    });

    test('(d) mapa parcial + lista de 4 com placeholders usa os slots', () {
      // Registo gravado antes de o mapa ficar completo: a lista mantém a
      // ordem nova (Frente, Lado 1, Lado 2, Costas) com slots vazios.
      final fotos = [front, side1, '', back];
      final mapa = {'Frente': front};

      expect(resolve(fotos, mapa, frente), front);
      expect(resolve(fotos, mapa, lado1), side1);
      expect(resolve(fotos, mapa, lado2), isNull);
      expect(resolve(fotos, mapa, costas), back);
    });

    test('4 slots com placeholders e sem mapa usam a ordem nova', () {
      final fotos = ['', side1, side2, ''];

      expect(resolve(fotos, const {}, frente), isNull);
      expect(resolve(fotos, const {}, lado1), side1);
      expect(resolve(fotos, const {}, lado2), side2);
      expect(resolve(fotos, const {}, costas), isNull);
    });
  });

  group('resolveProgressPhotoAt — registos antigos sem mapa', () {
    test('1 foto antiga é tratada como Frente', () {
      final fotos = [front];

      expect(resolve(fotos, const {}, frente), front);
      expect(resolve(fotos, const {}, lado1), isNull);
      expect(resolve(fotos, const {}, lado2), isNull);
      expect(resolve(fotos, const {}, costas), isNull);
    });

    test('(a) 2 fotos antigas: Frente + Lado 1', () {
      final fotos = [front, side1];

      expect(resolve(fotos, const {}, frente), front);
      expect(resolve(fotos, const {}, lado1), side1);
      expect(resolve(fotos, const {}, lado2), isNull);
      expect(resolve(fotos, const {}, costas), isNull);
    });

    test('(b) 3 fotos antigas: Frente + Lado 1 + Costas', () {
      final fotos = [front, side1, back];

      expect(resolve(fotos, const {}, frente), front);
      expect(resolve(fotos, const {}, lado1), side1);
      expect(resolve(fotos, const {}, costas), back);
      expect(resolve(fotos, const {}, lado2), isNull);
    });

    test('4 fotos antigas completas: Frente, Lado 1, Costas, Lado 2', () {
      // Ordem sugerida pelo formulário antigo: "frente, lado, costas,
      // opcional" — a 4.ª foto opcional é tratada como Lado 2.
      final fotos = [front, side1, back, side2];

      expect(resolve(fotos, const {}, frente), front);
      expect(resolve(fotos, const {}, lado1), side1);
      expect(resolve(fotos, const {}, costas), back);
      expect(resolve(fotos, const {}, lado2), side2);
    });

    test('mapa parcial + lista compacta não adivinha posições em falta', () {
      final fotos = [front, side1, back];
      final mapa = {'Frente': front};

      expect(resolve(fotos, mapa, frente), front);
      expect(resolve(fotos, mapa, lado1), isNull);
      expect(resolve(fotos, mapa, costas), isNull);
    });

    test('urls vazias ou índices inválidos devolvem null', () {
      expect(resolve(const [], const {}, frente), isNull);
      expect(resolve(const [front], const {}, -1), isNull);
      expect(resolve(const [front], const {}, 4), isNull);
      expect(resolve(const ['  '], const {}, frente), isNull);
    });
  });

  group('hasAnyProgressPhoto', () {
    test('deteta fotos na lista ou no mapa', () {
      expect(hasAnyProgressPhoto([front], const {}), isTrue);
      expect(hasAnyProgressPhoto(['', ' '], const {'Frente': front}), isTrue);
      expect(hasAnyProgressPhoto(['', ''], const {}), isFalse);
      expect(hasAnyProgressPhoto(const [], const {'Outra': front}), isFalse);
    });
  });
}
