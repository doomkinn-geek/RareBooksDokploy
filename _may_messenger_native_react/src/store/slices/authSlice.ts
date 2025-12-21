import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { jwtDecode } from 'jwt-decode';
import { User, LoginRequest, RegisterRequest, AuthResponse, UserRole } from '../../types';
import { STORAGE_KEYS } from '../../utils/constants';
import { authApi } from '../../api/authApi';

interface JWTPayload {
  sub: string;
  'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone': string;
  'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name': string;
  'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': string;
  exp: number;
}

function decodeUserFromToken(token: string): User {
  const decoded = jwtDecode<JWTPayload>(token);
  return {
    id: decoded.sub,
    phoneNumber: decoded['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone'],
    displayName: decoded['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'],
    role: decoded['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] === 'Admin' ? UserRole.Admin : UserRole.User,
    createdAt: new Date().toISOString(),
  };
}

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  loading: boolean;
  error: string | null;
}

const initialState: AuthState = {
  user: null,
  token: null,
  isAuthenticated: false,
  loading: false,
  error: null,
};

// Async Thunks
export const loginUser = createAsyncThunk(
  'auth/login',
  async (credentials: LoginRequest, { rejectWithValue }) => {
    try {
      const response = await authApi.login(credentials);
      
      if (response.success && response.token) {
        // Save token to AsyncStorage
        await AsyncStorage.setItem(STORAGE_KEYS.AUTH_TOKEN, response.token);
        const user = decodeUserFromToken(response.token);
        await AsyncStorage.setItem(STORAGE_KEYS.USER_DATA, JSON.stringify(user));
        return { token: response.token, user };
      } else {
        return rejectWithValue(response.message || 'Login failed');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Network error');
    }
  }
);

export const registerUser = createAsyncThunk(
  'auth/register',
  async (userData: RegisterRequest, { rejectWithValue }) => {
    try {
      const response = await authApi.register(userData);
      
      if (response.success && response.token) {
        // Save token to AsyncStorage
        await AsyncStorage.setItem(STORAGE_KEYS.AUTH_TOKEN, response.token);
        const user = decodeUserFromToken(response.token);
        await AsyncStorage.setItem(STORAGE_KEYS.USER_DATA, JSON.stringify(user));
        return { token: response.token, user };
      } else {
        return rejectWithValue(response.message || 'Registration failed');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Network error');
    }
  }
);

export const loadStoredAuth = createAsyncThunk(
  'auth/loadStored',
  async (_, { rejectWithValue }) => {
    try {
      const token = await AsyncStorage.getItem(STORAGE_KEYS.AUTH_TOKEN);
      const userData = await AsyncStorage.getItem(STORAGE_KEYS.USER_DATA);
      
      if (token) {
        let user: User | null = null;
        if (userData) {
          user = JSON.parse(userData);
        } else {
          // Decode from token if user data not saved
          user = decodeUserFromToken(token);
          await AsyncStorage.setItem(STORAGE_KEYS.USER_DATA, JSON.stringify(user));
        }
        return { token, user };
      } else {
        return rejectWithValue('No stored token');
      }
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const logoutUser = createAsyncThunk(
  'auth/logout',
  async () => {
    await AsyncStorage.removeItem(STORAGE_KEYS.AUTH_TOKEN);
    await AsyncStorage.removeItem(STORAGE_KEYS.USER_DATA);
    await AsyncStorage.removeItem(STORAGE_KEYS.FCM_TOKEN);
  }
);

// Slice
const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
    setUser: (state, action: PayloadAction<User>) => {
      state.user = action.payload;
    },
  },
  extraReducers: (builder) => {
    // Login
    builder.addCase(loginUser.pending, (state) => {
      state.loading = true;
      state.error = null;
    });
    builder.addCase(loginUser.fulfilled, (state, action) => {
      state.loading = false;
      state.token = action.payload.token;
      state.user = action.payload.user;
      state.isAuthenticated = true;
    });
    builder.addCase(loginUser.rejected, (state, action) => {
      state.loading = false;
      state.error = action.payload as string;
      state.isAuthenticated = false;
    });

    // Register
    builder.addCase(registerUser.pending, (state) => {
      state.loading = true;
      state.error = null;
    });
    builder.addCase(registerUser.fulfilled, (state, action) => {
      state.loading = false;
      state.token = action.payload.token;
      state.user = action.payload.user;
      state.isAuthenticated = true;
    });
    builder.addCase(registerUser.rejected, (state, action) => {
      state.loading = false;
      state.error = action.payload as string;
      state.isAuthenticated = false;
    });

    // Load stored
    builder.addCase(loadStoredAuth.pending, (state) => {
      state.loading = true;
    });
    builder.addCase(loadStoredAuth.fulfilled, (state, action) => {
      state.loading = false;
      state.token = action.payload.token;
      state.user = action.payload.user;
      state.isAuthenticated = true;
    });
    builder.addCase(loadStoredAuth.rejected, (state) => {
      state.loading = false;
      state.isAuthenticated = false;
    });

    // Logout
    builder.addCase(logoutUser.fulfilled, (state) => {
      state.user = null;
      state.token = null;
      state.isAuthenticated = false;
      state.error = null;
    });
  },
});

export const { clearError, setUser } = authSlice.actions;
export default authSlice.reducer;

