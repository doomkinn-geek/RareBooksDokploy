import '../datasources/api_datasource.dart';
import '../datasources/local_datasource.dart';
import '../models/auth_response.dart';

class AuthRepository {
  final ApiDataSource _apiDataSource;
  final LocalDataSource _localDataSource;

  AuthRepository(this._apiDataSource, this._localDataSource);

  Future<AuthResponse> register({
    required String phoneNumber,
    required String displayName,
    required String password,
    required String inviteCode,
  }) async {
    final response = await _apiDataSource.register(
      phoneNumber: phoneNumber,
      displayName: displayName,
      password: password,
      inviteCode: inviteCode,
    );

    if (response.success) {
      await _localDataSource.saveToken(response.token);
      _apiDataSource.setToken(response.token);
    }

    return response;
  }

  Future<AuthResponse> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _apiDataSource.login(
      phoneNumber: phoneNumber,
      password: password,
    );

    if (response.success) {
      await _localDataSource.saveToken(response.token);
      _apiDataSource.setToken(response.token);
    }

    return response;
  }

  Future<void> logout() async {
    await _localDataSource.clearToken();
    await _localDataSource.clearCache();
  }

  Future<String?> getStoredToken() async {
    return await _localDataSource.getToken();
  }

  Future<bool> isAuthenticated() async {
    final token = await getStoredToken();
    if (token != null) {
      _apiDataSource.setToken(token);
      return true;
    }
    return false;
  }
}


