/// Modelo imutável de Utilizador.
class UserModel {
  final String uid;
  final String nome;
  final String email;
  final String role; // 'aluno' ou 'admin'
  final double? pesoAtual;
  final double? altura;
  final String? fotoPerfil;
  final String? personalId; // UID do personal trainer associado
  final DateTime? ultimaAtividade;
  final bool hasPendingProgress; // Tem pedido de progresso pendente
  final DateTime? progressRequestedAt; // Quando o pedido foi feito
  final String? genero; // 'masculino', 'feminino' ou null
  final String tipoCliente; // 'presencial' ou 'online'

  const UserModel({
    required this.uid,
    required this.nome,
    required this.email,
    this.role = 'aluno',
    this.pesoAtual,
    this.altura,
    this.fotoPerfil,
    this.personalId,
    this.ultimaAtividade,
    this.hasPendingProgress = false,
    this.progressRequestedAt,
    this.genero,
    this.tipoCliente = 'presencial',
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
      fotoPerfil: map['fotoPerfil'] as String?,
      personalId: map['personalId'] as String?,
      ultimaAtividade: map['ultimaAtividade'] != null
          ? (map['ultimaAtividade'] as dynamic).toDate() as DateTime
          : null,
      hasPendingProgress: map['hasPendingProgress'] as bool? ?? false,
      progressRequestedAt: map['progressRequestedAt'] != null
          ? (map['progressRequestedAt'] as dynamic).toDate() as DateTime
          : null,
      genero: map['genero'] as String?,
      tipoCliente: map['tipoCliente'] as String? ?? 'presencial',
    );
  }

  /// Converte para mapa (para escrita no Firestore).
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'role': role,
      if (pesoAtual != null) 'pesoAtual': pesoAtual,
      if (altura != null) 'altura': altura,
      if (fotoPerfil != null) 'fotoPerfil': fotoPerfil,
      if (personalId != null) 'personalId': personalId,
      if (ultimaAtividade != null) 'ultimaAtividade': ultimaAtividade,
      'hasPendingProgress': hasPendingProgress,
      if (progressRequestedAt != null)
        'progressRequestedAt': progressRequestedAt,
      if (genero != null) 'genero': genero,
      'tipoCliente': tipoCliente,
    };
  }

  /// Cria uma cópia com campos alterados.
  UserModel copyWith({
    String? nome,
    String? email,
    String? role,
    double? pesoAtual,
    double? altura,
    String? fotoPerfil,
    String? personalId,
    DateTime? ultimaAtividade,
    bool clearPeso = false,
    bool clearAltura = false,
    bool clearFoto = false,
    bool clearPersonalId = false,
    String? genero,
    bool clearUltimaAtividade = false,
    String? tipoCliente,
  }) {
    return UserModel(
      uid: uid,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      role: role ?? this.role,
      pesoAtual: clearPeso ? null : (pesoAtual ?? this.pesoAtual),
      altura: clearAltura ? null : (altura ?? this.altura),
      fotoPerfil: clearFoto ? null : (fotoPerfil ?? this.fotoPerfil),
      personalId: clearPersonalId ? null : (personalId ?? this.personalId),
      ultimaAtividade:
          clearUltimaAtividade ? null : (ultimaAtividade ?? this.ultimaAtividade),
      genero: genero ?? this.genero,
      tipoCliente: tipoCliente ?? this.tipoCliente,
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

  String get tipoClienteDisplay {
    if (tipoCliente == 'online') return '💻 Online';
    return '🏋️ Presencial';
  }

  @override
  String toString() => 'UserModel(uid: $uid, nome: $nome, role: $role)';
}
