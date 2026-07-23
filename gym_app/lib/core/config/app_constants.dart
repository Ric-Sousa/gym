/// Constantes da aplicação.
class AppConstants {
  AppConstants._();

  // Water
  static const int dailyWaterGoalMl = 2500;
  static const int waterIncrementMl = 250;

  // Steps
  static const int dailyStepsGoal = 10000;

  // Rating
  static const int minRating = 1;
  static const int maxRating = 5;

  // Image quality
  static const int imageQuality = 70;
  static const int maxImageWidth = 1024;
  static const int maxImageHeight = 1024;

  // Chat
  static const int maxMessageLength = 1000;

  // Pagination
  static const int defaultPageSize = 20;

  // Date format
  static const String dateFormat = 'yyyy-MM-dd';
  static const String displayDateFormat = 'dd/MM/yyyy';
  static const String displayDateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Firebase collections
  static const String usersCollection = 'users';
  static const String diarySubcollection = 'diario';
  static const String nutritionPlanSubcollection = 'planoNutricao';
  static const String workoutPlanSubcollection = 'planoTreino';
  static const String progressSubcollection = 'progresso';
  static const String chatCollection = 'chat';
  static const String messagesSubcollection = 'mensagens';
  static const String foodsCollection = 'alimentos';
  static const String exercisesCollection = 'exercicios';

  // Storage paths
  static const String profilePhotoPath = 'users/{userId}/profile.jpg';
  static const String progressPhotoPath = 'users/{userId}/progresso/{timestamp}.jpg';
  static const String exerciseVideoPath = 'exercicios/{exerciseId}/video.mp4';

  // Roles
  static const String roleAluno = 'aluno';
  static const String roleAdmin = 'admin';

  // Chat room prefix
  static const String chatRoomPrefix = 'chat';

  // BMI categories
  static const Map<String, List<double>> bmiCategories = {
    'Abaixo do peso': [0, 18.5],
    'Peso normal': [18.5, 24.9],
    'Sobrepeso': [25.0, 29.9],
    'Obesidade Grau I': [30.0, 34.9],
    'Obesidade Grau II': [35.0, 39.9],
    'Obesidade Grau III': [40.0, double.infinity],
  };
}
