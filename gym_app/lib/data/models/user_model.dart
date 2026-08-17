/// Modelo imutável de Utilizador.
class UserModel {
  final String uid;
  final String nome;
  final String email;
  final String role; // 'aluno' ou 'admin'
  final double? pesoAtual;
  final double? altura;
  final DateTime? dataNascimento;
  final String? fotoPerfil;
  final String? personalId; // UID do personal trainer associado
  final DateTime? ultimaAtividade;

  /// Data em que o cliente foi registado na aplicação.
  final DateTime? createdAt;
  final bool hasPendingProgress; // Tem pedido de progresso pendente
  final DateTime? progressRequestedAt; // Quando o pedido foi feito
  final String? genero; // 'masculino', 'feminino' ou null
  final String tipoCliente; // 'presencial' ou 'online'
  final String? notificationSound; // asset path do som de notificação
  final bool soundEnabled; // se os sons de notificação estão ativos

  /// Controla se o aluno pode utilizar a aplicação.
  /// Perfis antigos continuam ativos por defeito.
  final bool isActive;

  /// Data/hora em que o contrato termina. Até lá o acesso mantém-se ativo.
  final DateTime? contractEndsAt;

  /// Data/hora em que o perfil foi desativado manualmente.
  final DateTime? deactivatedAt;

  /// Registo da aceitação da política de privacidade pelo utilizador.
  final DateTime? privacyPolicyAcceptedAt;
  final String? privacyPolicyVersion;

  /// Registo da conclusão da ficha inicial de anamnese.
  final DateTime? questionnaireCompletedAt;
  final String? questionnaireVersion;

  // A versão é o marcador de aceitação atómico; a data pode ficar
  // temporariamente nula enquanto o serverTimestamp é confirmado.
  bool get hasAcceptedPrivacyPolicy => privacyPolicyVersion != null;
  // A versão é o marcador de conclusão atómico, gravado juntamente com as
  // respostas. A data é informativa e pode faltar em perfis migrados.
  bool get hasCompletedQuestionnaire => questionnaireVersion != null;

  const UserModel({
    required this.uid,
    required this.nome,
    required this.email,
    this.role = 'aluno',
    this.pesoAtual,
    this.altura,
    this.dataNascimento,
    this.fotoPerfil,
    this.personalId,
    this.ultimaAtividade,
    this.createdAt,
    this.hasPendingProgress = false,
    this.progressRequestedAt,
    this.genero,
    this.tipoCliente = 'presencial',
    this.notificationSound,
    this.soundEnabled = true,
    this.isActive = true,
    this.contractEndsAt,
    this.deactivatedAt,
    this.privacyPolicyAcceptedAt,
    this.privacyPolicyVersion,
    this.questionnaireCompletedAt,
    this.questionnaireVersion,
  });

  /// Cria a partir do documento Firestore.
  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      nome: map['nome'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'aluno',
      pesoAtual: (map['pesoAtual'] as num?)?.toDouble(),
      altura: (map['altura'] as num?)?.toDouble(),
      dataNascimento: _dateFromMap(map['dataNascimento']),
      fotoPerfil: map['fotoPerfil'] as String?,
      personalId: map['personalId'] as String?,
      ultimaAtividade: map['ultimaAtividade'] != null
          ? (map['ultimaAtividade'] as dynamic).toDate() as DateTime
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate() as DateTime
          : null,
      hasPendingProgress: map['hasPendingProgress'] as bool? ?? false,
      progressRequestedAt: map['progressRequestedAt'] != null
          ? (map['progressRequestedAt'] as dynamic).toDate() as DateTime
          : null,
      genero: map['genero'] as String?,
      tipoCliente: map['tipoCliente'] as String? ?? 'presencial',
      notificationSound: map['notificationSound'] as String?,
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      isActive: map['isActive'] as bool? ?? true,
      contractEndsAt: _dateFromMap(map['contractEndsAt']),
      deactivatedAt: _dateFromMap(map['deactivatedAt']),
      privacyPolicyAcceptedAt: _dateFromMap(map['privacyPolicyAcceptedAt']),
      privacyPolicyVersion: map['privacyPolicyVersion'] as String?,
      questionnaireCompletedAt: _dateFromMap(map['questionnaireCompletedAt']),
      questionnaireVersion: map['questionnaireVersion'] as String?,
    );
  }

  static DateTime? _dateFromMap(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }

  /// Converte para mapa (para escrita no Firestore).
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'role': role,
      if (pesoAtual != null) 'pesoAtual': pesoAtual,
      if (altura != null) 'altura': altura,
      if (dataNascimento != null) 'dataNascimento': dataNascimento,
      if (fotoPerfil != null) 'fotoPerfil': fotoPerfil,
      if (personalId != null) 'personalId': personalId,
      if (ultimaAtividade != null) 'ultimaAtividade': ultimaAtividade,
      if (createdAt != null) 'createdAt': createdAt,
      'hasPendingProgress': hasPendingProgress,
      if (progressRequestedAt != null)
        'progressRequestedAt': progressRequestedAt,
      if (genero != null) 'genero': genero,
      'tipoCliente': tipoCliente,
      if (notificationSound != null) 'notificationSound': notificationSound,
      if (!soundEnabled)
        'soundEnabled': false, // só escreve se for false (poupa writes)
      'isActive': isActive,
      if (contractEndsAt != null) 'contractEndsAt': contractEndsAt,
      if (deactivatedAt != null) 'deactivatedAt': deactivatedAt,
      if (privacyPolicyAcceptedAt != null)
        'privacyPolicyAcceptedAt': privacyPolicyAcceptedAt,
      if (privacyPolicyVersion != null)
        'privacyPolicyVersion': privacyPolicyVersion,
      if (questionnaireCompletedAt != null)
        'questionnaireCompletedAt': questionnaireCompletedAt,
      if (questionnaireVersion != null)
        'questionnaireVersion': questionnaireVersion,
    };
  }

  /// Cria uma cópia com campos alterados.
  UserModel copyWith({
    String? nome,
    String? email,
    String? role,
    double? pesoAtual,
    double? altura,
    DateTime? dataNascimento,
    String? fotoPerfil,
    String? personalId,
    DateTime? ultimaAtividade,
    DateTime? createdAt,
    bool clearPeso = false,
    bool clearAltura = false,
    bool clearFoto = false,
    bool clearPersonalId = false,
    String? genero,
    bool clearUltimaAtividade = false,
    String? tipoCliente,
    String? notificationSound,
    bool? soundEnabled,
    bool? isActive,
    DateTime? contractEndsAt,
    DateTime? deactivatedAt,
    bool clearContractEndsAt = false,
    bool clearDeactivatedAt = false,
    DateTime? privacyPolicyAcceptedAt,
    String? privacyPolicyVersion,
    DateTime? questionnaireCompletedAt,
    String? questionnaireVersion,
  }) {
    return UserModel(
      uid: uid,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      role: role ?? this.role,
      pesoAtual: clearPeso ? null : (pesoAtual ?? this.pesoAtual),
      altura: clearAltura ? null : (altura ?? this.altura),
      dataNascimento: dataNascimento ?? this.dataNascimento,
      fotoPerfil: clearFoto ? null : (fotoPerfil ?? this.fotoPerfil),
      personalId: clearPersonalId ? null : (personalId ?? this.personalId),
      ultimaAtividade: clearUltimaAtividade
          ? null
          : (ultimaAtividade ?? this.ultimaAtividade),
      createdAt: createdAt ?? this.createdAt,
      genero: genero ?? this.genero,
      tipoCliente: tipoCliente ?? this.tipoCliente,
      notificationSound: notificationSound ?? this.notificationSound,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      isActive: isActive ?? this.isActive,
      contractEndsAt: clearContractEndsAt
          ? null
          : (contractEndsAt ?? this.contractEndsAt),
      deactivatedAt: clearDeactivatedAt
          ? null
          : (deactivatedAt ?? this.deactivatedAt),
      privacyPolicyAcceptedAt:
          privacyPolicyAcceptedAt ?? this.privacyPolicyAcceptedAt,
      privacyPolicyVersion: privacyPolicyVersion ?? this.privacyPolicyVersion,
      questionnaireCompletedAt:
          questionnaireCompletedAt ?? this.questionnaireCompletedAt,
      questionnaireVersion: questionnaireVersion ?? this.questionnaireVersion,
    );
  }

  /// Calcula o IMC.
  double? get imc {
    if (pesoAtual == null || altura == null || altura! <= 0) return null;
    return pesoAtual! / ((altura! / 100) * (altura! / 100));
  }

  /// Categoria do IMC.
  String? get imcCategory {
    final bmi = imc;
    if (bmi == null) return null;
    if (bmi < 18.5) return 'Abaixo do peso';
    if (bmi < 25) return 'Peso normal';
    if (bmi < 30) return 'Sobrepeso';
    if (bmi < 35) return 'Obesidade Grau I';
    if (bmi < 40) return 'Obesidade Grau II';
    return 'Obesidade Grau III';
  }

  /// Texto amigável para o género.
  String get generoDisplay {
    if (genero == 'masculino') return '💪 Masculino';
    if (genero == 'feminino') return '🌸 Feminino';
    return 'Não definido';
  }

  bool get isAdmin => role == 'admin';
  bool get isAluno => role == 'aluno';
  bool get isOnline => tipoCliente == 'online';

  /// O acesso pode terminar por desativação manual ou pela data de contrato.
  bool get isAccessAllowed =>
      isAdmin ||
      (isActive &&
          (contractEndsAt == null || contractEndsAt!.isAfter(DateTime.now())));

  String get accessStatus {
    if (!isActive) return 'Inativo';
    if (contractEndsAt != null && !contractEndsAt!.isAfter(DateTime.now())) {
      return 'Contrato terminado';
    }
    if (contractEndsAt != null) return 'Termina em breve';
    return 'Ativo';
  }

  String get tipoClienteDisplay {
    if (tipoCliente == 'online') return '💻 Online';
    return '🏋️ Presencial';
  }

  @override
  String toString() => 'UserModel(uid: $uid, nome: $nome, role: $role)';
}
