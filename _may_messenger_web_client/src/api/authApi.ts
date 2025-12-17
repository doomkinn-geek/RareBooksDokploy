import { apiClient } from './apiClient';
import { AuthResponse, LoginRequest, RegisterRequest, UserProfile } from '../types/auth';
import { ENDPOINTS } from '../utils/constants';

export const authApi = {
  async login(data: LoginRequest): Promise<AuthResponse> {
    const response = await apiClient.post<AuthResponse>(ENDPOINTS.LOGIN, data);
    return response.data;
  },

  async register(data: RegisterRequest): Promise<AuthResponse> {
    const response = await apiClient.post<AuthResponse>(ENDPOINTS.REGISTER, data);
    return response.data;
  },

  async getUserProfile(): Promise<UserProfile> {
    const response = await apiClient.get<UserProfile>(ENDPOINTS.USER_PROFILE);
    return response.data;
  },

  async getAllUsers(): Promise<UserProfile[]> {
    const response = await apiClient.get<UserProfile[]>(ENDPOINTS.USERS);
    return response.data;
  },

  async createInviteLink(): Promise<{ code: string; inviteLink: string }> {
    const response = await apiClient.post(ENDPOINTS.CREATE_INVITE);
    return response.data;
  },

  async getMyInviteLinks(): Promise<any[]> {
    const response = await apiClient.get(ENDPOINTS.MY_INVITES);
    return response.data;
  },

  async validateInviteCode(code: string): Promise<{ isValid: boolean; message?: string }> {
    const response = await apiClient.post(ENDPOINTS.VALIDATE_INVITE, { code });
    return response.data;
  },
};
