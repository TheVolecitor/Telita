import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'watch_history.dart';

const String defaultApiUrl = 'https://telita.thevolecitor.qzz.io';

class AuthUser {
  final String id;
  final String email;

  AuthUser({required this.id, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser && runtimeType == other.runtimeType && id == other.id && email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}

class AuthProfile {
  final String id;
  final String name;
  final String? avatarUrl;
  final int position;
  final bool? hasPin;
  final String? pinHash;

  AuthProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.position,
    this.hasPin,
    this.pinHash,
  });

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    return AuthProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      position: json['position'] ?? 0,
      hasPin: json['has_pin'] == true || json['has_pin'] == 1,
      pinHash: json['pin_hash'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_url': avatarUrl,
        'position': position,
        if (hasPin != null) 'has_pin': hasPin,
        if (pinHash != null) 'pin_hash': pinHash,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          avatarUrl == other.avatarUrl &&
          position == other.position &&
          hasPin == other.hasPin &&
          pinHash == other.pinHash;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      avatarUrl.hashCode ^
      position.hashCode ^
      hasPin.hashCode ^
      pinHash.hashCode;
}

class AuthState {
  final String? token;
  final AuthUser? user;
  final List<AuthProfile> profiles;
  final AuthProfile? profile;
  final bool isGuest;
  final bool ready;

  AuthState({
    this.token,
    this.user,
    this.profiles = const [],
    this.profile,
    this.isGuest = false,
    this.ready = false,
  });

  AuthState copyWith({
    String? token,
    AuthUser? user,
    List<AuthProfile>? profiles,
    AuthProfile? profile,
    bool? isGuest,
    bool? ready,
  }) {
    return AuthState(
      token: token ?? this.token,
      user: user ?? this.user,
      profiles: profiles ?? this.profiles,
      profile: profile ?? this.profile,
      isGuest: isGuest ?? this.isGuest,
      ready: ready ?? this.ready,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AuthState) return false;
    
    bool profilesEqual = profiles.length == other.profiles.length;
    if (profilesEqual) {
      for (int i = 0; i < profiles.length; i++) {
        if (profiles[i] != other.profiles[i]) {
          profilesEqual = false;
          break;
        }
      }
    }

    return token == other.token &&
        user == other.user &&
        profile == other.profile &&
        isGuest == other.isGuest &&
        ready == other.ready &&
        profilesEqual;
  }

  @override
  int get hashCode =>
      token.hashCode ^
      user.hashCode ^
      profile.hashCode ^
      isGuest.hashCode ^
      ready.hashCode ^
      profiles.length.hashCode;
}

class AuthService extends ValueNotifier<AuthState> {
  static final AuthService instance = AuthService._internal();
  AuthService._internal() : super(AuthState());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('telita_token');
    final profileId = prefs.getString('telita_profile_id');
    final guest = prefs.getBool('telita_guest') ?? false;

    if (guest) {
      value = AuthState(isGuest: true, ready: true);
      return;
    }

    if (token != null) {
      try {
        final res = await http.get(
          Uri.parse('$defaultApiUrl/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final user = AuthUser.fromJson(data['user']);
          final profiles = (data['profiles'] as List)
              .map((e) => AuthProfile.fromJson(e))
              .toList();
          AuthProfile? profile;
          if (profileId != null) {
            try {
              profile = profiles.firstWhere((p) => p.id == profileId);
              if (profile.hasPin == true) {
                profile = null;
              }
            } catch (_) {}
          }
          if (profile == null && profiles.length == 1 && profiles[0].hasPin != true) {
            profile = profiles[0];
          }

          value = AuthState(
            token: token,
            user: user,
            profiles: profiles,
            profile: profile,
            isGuest: false,
            ready: true,
          );
          if (profile != null) {
            await prefs.setString('telita_profile_id', profile.id);
          } else {
            await prefs.remove('telita_profile_id');
          }
          await WatchHistory.instance.setProfile(profile?.id, token);
          return;
        }
      } catch (e) {
        print("Auth check failed: $e");
      }
      // Token invalid, clear it
      await prefs.remove('telita_token');
    }

    value = AuthState(ready: true);
    await WatchHistory.instance.setProfile(null, null);
  }

  Future<Map<String, dynamic>> register(String email, String password, {String? name}) async {
    try {
      final res = await http.post(
        Uri.parse('$defaultApiUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, if (name != null) 'name': name}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) return {'error': data['error'] ?? 'Registration failed'};
      await _applyLoginResponse(data);
      return {};
    } catch (e) {
      return {'error': 'Network error. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$defaultApiUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) return {'error': data['error'] ?? 'Login failed'};
      await _applyLoginResponse(data);
      return {};
    } catch (e) {
      return {'error': 'Network error. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> getDeviceCode() async {
    try {
      final res = await http.post(
        Uri.parse('$defaultApiUrl/api/auth/device/code'),
        headers: {'Content-Type': 'application/json'},
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'error': 'Network error. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> pollDeviceToken(String deviceCode) async {
    try {
      final res = await http.post(
        Uri.parse('$defaultApiUrl/api/auth/device/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_code': deviceCode}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await _applyLoginResponse(data);
        return {'success': true};
      }
      return data;
    } catch (e) {
      return {'error': 'Network error'};
    }
  }

  Future<void> logout() async {
    final token = value.token;
    if (token != null) {
      http.post(
        Uri.parse('$defaultApiUrl/api/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      ).catchError((_) {});
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('telita_token');
    await prefs.remove('telita_profile_id');
    await prefs.remove('telita_guest');
    value = AuthState(ready: true);
    await WatchHistory.instance.setProfile(null, null);
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('telita_guest', true);
    value = AuthState(isGuest: true, ready: true);
    await WatchHistory.instance.setProfile(null, null);
  }

  Future<bool> unlockProfile(String profileId, String pin) async {
    final profile = value.profiles.firstWhere((p) => p.id == profileId, orElse: () => throw Exception('Profile not found'));
    
    if (profile.pinHash == null || profile.pinHash!.isEmpty) {
      return true; // No PIN required
    }
    
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    final hexHash = digest.toString();
    
    return hexHash == profile.pinHash;
  }

  Future<void> selectProfile(AuthProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('telita_profile_id', profile.id);
    value = value.copyWith(profile: profile);
    await WatchHistory.instance.setProfile(profile.id, value.token);
  }

  void updateProfiles(List<AuthProfile> profiles) {
    final activeProfile = profiles.firstWhere((p) => p.id == value.profile?.id,
        orElse: () => profiles.isNotEmpty ? profiles[0] : null as dynamic);
    value = value.copyWith(profiles: profiles, profile: activeProfile);
  }

  Future<Map<String, dynamic>> addProfile(String name, {String? avatarUrl}) async {
    if (value.token == null) return {'error': 'Not logged in'};
    try {
      final res = await http.post(
        Uri.parse('$defaultApiUrl/api/profiles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${value.token}'
        },
        body: jsonEncode({
          'name': name,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 201) return {'error': data['error'] ?? 'Failed to add profile'};
      
      final newProfile = AuthProfile.fromJson(data);
      updateProfiles([...value.profiles, newProfile]);
      return {};
    } catch (e) {
      return {'error': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> updateProfile(String id, {String? name, String? avatarUrl, String? pin, String? currentPin}) async {
    if (value.token == null) return {'error': 'Not logged in'};
    try {
      final res = await http.put(
        Uri.parse('$defaultApiUrl/api/profiles/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${value.token}'
        },
        body: jsonEncode({
          if (name != null) 'name': name,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (pin != null) 'pin': pin,
          if (currentPin != null) 'current_pin': currentPin,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) return {'error': data['error'] ?? 'Failed to update profile'};
      
      final updatedProfile = AuthProfile.fromJson(data);
      final updatedList = value.profiles.map((p) => p.id == id ? updatedProfile : p).toList();
      updateProfiles(updatedList);
      return {};
    } catch (e) {
      return {'error': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> deleteProfile(String id) async {
    if (value.token == null) return {'error': 'Not logged in'};
    if (value.profiles.length <= 1) return {'error': 'Cannot delete the last profile'};
    try {
      final res = await http.delete(
        Uri.parse('$defaultApiUrl/api/profiles/$id'),
        headers: headers(),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) return {'error': data['error'] ?? 'Failed to delete profile'};
      
      final updatedList = value.profiles.where((p) => p.id != id).toList();
      updateProfiles(updatedList);
      
      if (value.profile?.id == id && updatedList.isNotEmpty) {
        await selectProfile(updatedList.first);
      }
      return {};
    } catch (e) {
      return {'error': 'Network error'};
    }
  }


  Future<void> _applyLoginResponse(Map<String, dynamic> data) async {
    final token = data['token'];
    Map<String, dynamic> responseData = data;
    
    // If device auth didn't return user/profiles, fetch them explicitly
    if (responseData['user'] == null || responseData['profiles'] == null) {
      final res = await http.get(
        Uri.parse('$defaultApiUrl/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        responseData = jsonDecode(res.body);
        responseData['token'] = token;
      } else {
        throw Exception('Failed to fetch user details');
      }
    }

    final user = AuthUser.fromJson(responseData['user']);
    final profiles = (responseData['profiles'] as List)
        .map((e) => AuthProfile.fromJson(e))
        .toList();
    AuthProfile? profile;
    if (profiles.length == 1 && profiles[0].hasPin != true) {
      profile = profiles[0];
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('telita_token', token);
    await prefs.remove('telita_guest');
    if (profile != null) {
      await prefs.setString('telita_profile_id', profile.id);
    } else {
      await prefs.remove('telita_profile_id');
    }

    value = AuthState(
      token: token,
      user: user,
      profiles: profiles,
      profile: profile,
      isGuest: false,
      ready: true,
    );
    await WatchHistory.instance.setProfile(profile?.id, token);
  }

  Map<String, String> headers() {
    final t = value.token;
    return t != null
        ? {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'}
        : {'Content-Type': 'application/json'};
  }
}
