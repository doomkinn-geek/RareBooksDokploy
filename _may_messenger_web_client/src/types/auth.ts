export interface AuthResponse {
  token: string;
  user: UserProfile;
}

export interface LoginRequest {
  phoneNumber: string;
  password: string;
}

export interface RegisterRequest {
  phoneNumber: string;
  displayName: string;
  password: string;
  inviteCode: string;
}

export interface UserProfile {
  id: string;
  phoneNumber: string;
  displayName: string;
  role: UserRole;
  createdAt: string;
}

export enum UserRole {
  User = 0,
  Admin = 1,
}
