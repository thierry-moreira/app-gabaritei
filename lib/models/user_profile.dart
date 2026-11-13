import '../core/utils/json_utils.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.email,
    this.metaDiaria = 0,
    this.tema,
    this.authId,
  });

  final int id;
  final String username;
  final String? email;
  final int metaDiaria;
  final String? tema;
  final String? authId;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: Json.integer(map['id']),
    username: Json.text(map['username'], 'Estudante'),
    email: Json.textOrNull(map['email']),
    metaDiaria: Json.integer(map['meta_diaria']),
    tema: Json.textOrNull(map['tema']),
    authId: Json.textOrNull(map['auth_id']),
  );

  UserProfile copyWith({
    String? username,
    String? email,
    int? metaDiaria,
    String? tema,
  }) => UserProfile(
    id: id,
    username: username ?? this.username,
    email: email ?? this.email,
    metaDiaria: metaDiaria ?? this.metaDiaria,
    tema: tema ?? this.tema,
    authId: authId,
  );
}
