import { MD3LightTheme, MD3DarkTheme } from 'react-native-paper';

export const lightTheme = {
  ...MD3LightTheme,
  colors: {
    ...MD3LightTheme.colors,
    primary: '#2196F3',
    primaryContainer: '#E3F2FD',
    secondary: '#03A9F4',
    secondaryContainer: '#B3E5FC',
    background: '#FFFFFF',
    surface: '#F5F5F5',
    surfaceVariant: '#E0E0E0',
    error: '#F44336',
    errorContainer: '#FFEBEE',
    onPrimary: '#FFFFFF',
    onSecondary: '#FFFFFF',
    onBackground: '#000000',
    onSurface: '#000000',
    onError: '#FFFFFF',
    outline: '#BDBDBD',
  },
  roundness: 12,
};

export const darkTheme = {
  ...MD3DarkTheme,
  colors: {
    ...MD3DarkTheme.colors,
    primary: '#2196F3',
    primaryContainer: '#0D47A1',
    secondary: '#03A9F4',
    secondaryContainer: '#01579B',
    background: '#121212',
    surface: '#1E1E1E',
    surfaceVariant: '#2C2C2C',
    error: '#EF5350',
    errorContainer: '#B71C1C',
    onPrimary: '#FFFFFF',
    onSecondary: '#FFFFFF',
    onBackground: '#FFFFFF',
    onSurface: '#FFFFFF',
    onError: '#FFFFFF',
    outline: '#424242',
  },
  roundness: 12,
};

// Custom colors for messages
export const messageColors = {
  light: {
    sentBubble: '#E3F2FD',
    receivedBubble: '#F5F5F5',
    sentText: '#000000',
    receivedText: '#000000',
    timestamp: '#757575',
  },
  dark: {
    sentBubble: '#0D47A1',
    receivedBubble: '#2C2C2C',
    sentText: '#FFFFFF',
    receivedText: '#FFFFFF',
    timestamp: '#9E9E9E',
  },
};

