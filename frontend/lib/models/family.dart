class Family {
  final int id;
  final String name;
  final String? inviteCode;
  final DateTime? inviteExpiresAt;
  final DateTime createdAt;
  final bool isActive;

  const Family({
    required this.id,
    required this.name,
    this.inviteCode,
    this.inviteExpiresAt,
    required this.createdAt,
    this.isActive = true,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as int,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String?,
      inviteExpiresAt: json['invite_expires_at'] != null
          ? DateTime.parse(json['invite_expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'invite_expires_at': inviteExpiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }
}

class FamilyMember {
  final int id;
  final int familyId;
  final int userId;
  final String roleInFamily;
  final DateTime joinedAt;
  final String? userName;

  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.roleInFamily,
    required this.joinedAt,
    this.userName,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      userId: json['user_id'] as int,
      roleInFamily: json['role_in_family'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      userName: json['user_name'] as String?,
    );
  }
}

class DeviceProvider {
  final int id;
  final int familyId;
  final String deviceType;
  final String providerType;
  final Map<String, dynamic>? providerSettings;

  const DeviceProvider({
    required this.id,
    required this.familyId,
    required this.deviceType,
    required this.providerType,
    this.providerSettings,
  });

  factory DeviceProvider.fromJson(Map<String, dynamic> json) {
    return DeviceProvider(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      deviceType: json['device_type'] as String,
      providerType: json['provider_type'] as String,
      providerSettings: json['provider_settings'] as Map<String, dynamic>?,
    );
  }
}

class RewardProviderInfo {
  final String code;
  final String name;
  final String? description;
  final bool requiresTanPool;

  const RewardProviderInfo({
    required this.code,
    required this.name,
    this.description,
    this.requiresTanPool = false,
  });

  factory RewardProviderInfo.fromJson(Map<String, dynamic> json) {
    return RewardProviderInfo(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      requiresTanPool: json['requires_tan_pool'] as bool? ?? false,
    );
  }
}
