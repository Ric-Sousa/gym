import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/data/models/exercise_catalog_model.dart';

void main() {
  group('ExerciseCatalogModel', () {
    test('converte o formato do catálogo externo', () {
      final exercise = ExerciseCatalogModel.fromSourceMap({
        'id': 'Barbell_Squat',
        'name': 'Agachamento com Barra',
        'level': 'beginner',
        'category': 'strength',
        'equipment': 'barbell',
        'primaryMuscles': ['quadriceps'],
        'secondaryMuscles': ['glutes'],
        'instructions': ['Posicione a barra.', 'Desça com controlo.'],
        'images': ['Barbell_Squat/0.jpg'],
      });

      expect(exercise.id, 'Barbell_Squat');
      expect(exercise.nome, 'Agachamento com Barra');
      expect(exercise.nivel, 'beginner');
      expect(exercise.categoria, 'forca');
      expect(exercise.equipamento, 'barra');
      expect(exercise.grupoMuscular, 'Quadríceps');
      expect(exercise.musculosPrimarios, ['Quadríceps']);
      expect(exercise.instrucoes, hasLength(2));
      expect(exercise.origemId, 'Barbell_Squat');
      expect(exercise.ativo, isTrue);
    });

    test('preserva os campos completos no mapa Firestore', () {
      const exercise = ExerciseCatalogModel(
        id: 'supino',
        nome: 'Supino reto',
        instrucoes: ['Deitar.', 'Empurrar.'],
        nivel: 'intermediario',
        categoria: 'forca',
        equipamento: 'barra',
        musculosPrimarios: ['peito'],
        musculosSecundarios: ['triceps'],
        origem: 'catalogo',
        origemId: 'supino-source',
      );

      final map = exercise.toMap();
      final restored = ExerciseCatalogModel.fromMap('supino', map);

      expect(restored.nome, exercise.nome);
      expect(restored.instrucoes, exercise.instrucoes);
      expect(restored.equipamento, exercise.equipamento);
      expect(restored.musculosSecundarios, ['Tríceps']);
      expect(restored.origemId, 'supino-source');
    });

    test('categoriza músculos em grupos principais consistentes', () {
      expect(
        ExerciseCatalogModel.canonicalMuscleGroup('chest'),
        'Peito',
      );
      expect(
        ExerciseCatalogModel.canonicalMuscleGroup('hamstrings'),
        'Posterior',
      );
      expect(
        ExerciseCatalogModel.canonicalMuscleGroup('glutes'),
        'Glúteos',
      );
      expect(
        ExerciseCatalogModel.canonicalMuscleGroup('quadríceps'),
        'Quadríceps',
      );
      expect(
        ExerciseCatalogModel.canonicalMuscleGroup('lower back'),
        'Lombar',
      );
    });

    test('normaliza equipamentos conhecidos e mantém desconhecidos', () {
      expect(
        ExerciseCatalogModel.fromSourceMap({
          'id': 'a',
          'name': 'A',
          'equipment': 'body only',
        }).equipamento,
        'peso_corporal',
      );
      expect(
        ExerciseCatalogModel.fromSourceMap({
          'id': 'b',
          'name': 'B',
          'equipment': 'equipamento especial',
        }).equipamento,
        'equipamento especial',
      );
    });
  });
}
