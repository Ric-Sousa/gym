/// Strings estáticas da aplicação (Português).
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'PersonalFit';
  static const String appTagline = 'O teu personal trainer digital';

  // Auth
  static const String login = 'Entrar';
  static const String email = 'E-mail';
  static const String password = 'Palavra-passe';
  static const String forgotPassword = 'Recuperar palavra-passe';
  static const String emailHint = 'exemplo@email.com';
  static const String passwordHint = 'Mínimo 6 caracteres';
  static const String invalidEmail = 'E-mail inválido';
  static const String invalidPassword = 'A palavra-passe deve ter pelo menos 6 caracteres';
  static const String loginError = 'Erro ao iniciar sessão';
  static const String userNotFound = 'Utilizador não encontrado';
  static const String wrongPassword = 'Palavra-passe incorreta';
  static const String accountDisabled = 'Conta desativada. Contacta o suporte.';
  static const String passwordResetSent = 'E-mail de recuperação enviado. Verifica a tua caixa de entrada.';
  static const String noUserDoc = 'Documento de utilizador não encontrado. Contacta o suporte.';

  // Navigation
  static const String tabHome = 'Início';
  static const String tabNutrition = 'Nutrição';
  static const String tabWorkout = 'Treino';
  static const String tabChat = 'Chat';
  static const String tabProfile = 'Perfil';

  // Dashboard
  static const String waterTitle = 'Água';
  static const String waterUnit = 'ml';
  static const String waterGoal = 'Meta: 2500 ml';
  static const String addWater = '+250 ml';
  static const String stepsTitle = 'Passos';
  static const String stepsGoal = 'Meta: 10000';
  static const String mealsTitle = 'Refeições';
  static const String caloriesConsumed = 'Calorias consumidas';
  static const String caloriesGoal = 'Meta calórica';
  static const String dayRating = 'Avaliação do dia';
  static const String noDiaryEntry = 'Nenhum registo diário encontrado';

  // Nutrition
  static const String nutritionPlan = 'Plano Nutricional';
  static const String noPlanAssigned = 'Nenhum plano nutricional atribuído.\nContacta o teu personal trainer.';
  static const String addExtraMeal = 'Adicionar refeição extra';
  static const String searchFood = 'Pesquisar alimento...';
  static const String mealCompleted = 'Refeição concluída!';
  static const String caloriesLabel = 'calorias';
  static const String proteinLabel = 'proteínas';
  static const String carbsLabel = 'hidratos';
  static const String fatLabel = 'gorduras';

  // Workout
  static const String workoutPlan = 'Plano de Treino';
  static const String restDay = 'Dia de Descanso 🧘';
  static const String restDayMessage = 'Hoje é dia de recuperação. Aproveita para alongar!';
  static const String noWorkoutAssigned = 'Nenhum treino atribuído para hoje.';
  static const String sets = 'Séries';
  static const String reps = 'Repetições';
  static const String rest = 'Descanso';
  static const String seconds = 's';
  static const String suggestedLoad = 'Carga sugerida';
  static const String actualLoad = 'Carga real';
  static const String observations = 'Observações';
  static const String workoutCompleted = 'Treino concluído! 💪';
  static const String workoutHistory = 'Histórico de Treinos';
  static const String checkIn = 'Check-in';
  static const String watchVideo = 'Ver vídeo';

  // Chat
  static const String chatTitle = 'Mensagens';
  static const String typeMessage = 'Escreve uma mensagem...';
  static const String send = 'Enviar';
  static const String noMessages = 'Nenhuma mensagem. Começa a conversa!';
  static const String messageSendError = 'Erro ao enviar mensagem. Tenta novamente.';

  // Profile
  static const String profile = 'Perfil';
  static const String editProfile = 'Editar Perfil';
  static const String changePhoto = 'Alterar foto';
  static const String weight = 'Peso';
  static const String height = 'Altura';
  static const String bmi = 'IMC';
  static const String weightEvolution = 'Evolução do Peso';
  static const String progressPhotos = 'Fotos de Progresso';
  static const String addPhoto = 'Adicionar foto';
  static const String noProgressData = 'Sem dados de progresso ainda.';
  static const String save = 'Guardar';
  static const String cancel = 'Cancelar';
  static const String logout = 'Terminar sessão';

  // Admin
  static const String adminPanel = 'Painel Admin';
  static const String students = 'Alunos';
  static const String searchStudent = 'Pesquisar aluno...';
  static const String noStudents = 'Nenhum aluno registado.';
  static const String studentDetail = 'Detalhe do Aluno';
  static const String exportReport = 'Exportar Relatório PDF';
  static const String editNutrition = 'Editar Nutrição';
  static const String editWorkout = 'Editar Treino';

  // Days of week
  static const List<String> daysOfWeek = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  static const List<String> daysOfWeekShort = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  // Connectivity
  static const String offlineMessage = 'Estás offline. Algumas funcionalidades podem não estar disponíveis.';
  static const String retry = 'Tentar novamente';

  // Errors
  static const String genericError = 'Ocorreu um erro. Tenta novamente.';
  static const String networkError = 'Erro de ligação. Verifica a tua internet.';
  static const String permissionDenied = 'Permissão negada. Verifica as definições.';
  static const String uploadError = 'Erro ao fazer upload. Tenta novamente.';

  // PDF Report
  static const String reportTitle = 'Relatório de Progresso';
  static const String generatedOn = 'Gerado em';
  static const String reportFor = 'Relatório de';
}
