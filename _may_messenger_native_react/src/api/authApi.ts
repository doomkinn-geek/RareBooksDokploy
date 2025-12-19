import { apiClient } from './apiClient';
import { API_ENDPOINTS } from '../utils/constants';
import { AuthResponse, LoginRequest, RegisterRequest } from '../types';

export const authApi = {
  async login(credentials: LoginRequest): Promise<AuthResponse> {
    return await apiClient.post<AuthResponse>(API_ENDPOINTS.AUTH.LOGIN, credentials);
  },

  async register(userData: RegisterRequest): Promise<AuthResponse> {
    return await apiClient.post<AuthResponse>(API_ENDPOINTS.AUTH.REGISTER, userData);
  },
};

