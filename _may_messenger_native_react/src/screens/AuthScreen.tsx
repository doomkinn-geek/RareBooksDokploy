import React, { useState } from 'react';
import { View, StyleSheet, KeyboardAvoidingView, Platform, ScrollView, Modal } from 'react-native';
import { TextInput, Button, Text, Surface, useTheme, IconButton } from 'react-native-paper';
import { useAppDispatch, useAppSelector } from '../store';
import { loginUser, registerUser, clearError } from '../store/slices/authSlice';
import QRScanner from '../components/QRScanner';

const AuthScreen: React.FC = () => {
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const { loading, error } = useAppSelector((state) => state.auth);

  const [isLogin, setIsLogin] = useState(true);
  const [phoneNumber, setPhoneNumber] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [password, setPassword] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [showQRScanner, setShowQRScanner] = useState(false);

  const handleSubmit = () => {
    dispatch(clearError());
    
    if (isLogin) {
      dispatch(loginUser({ phoneNumber, password }));
    } else {
      dispatch(registerUser({ phoneNumber, displayName, password, inviteCode }));
    }
  };

  const toggleMode = () => {
    setIsLogin(!isLogin);
    dispatch(clearError());
  };

  const handleQRScan = (code: string) => {
    setInviteCode(code);
    setShowQRScanner(false);
  };

  return (
    <KeyboardAvoidingView 
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView 
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        <Surface style={styles.surface} elevation={4}>
          <Text variant="headlineMedium" style={styles.title}>
            {isLogin ? 'Вход' : 'Регистрация'}
          </Text>
          
          <TextInput
            label="Номер телефона"
            value={phoneNumber}
            onChangeText={setPhoneNumber}
            mode="outlined"
            style={styles.input}
            keyboardType="phone-pad"
            autoCapitalize="none"
            disabled={loading}
          />
          
          {!isLogin && (
            <TextInput
              label="Имя"
              value={displayName}
              onChangeText={setDisplayName}
              mode="outlined"
              style={styles.input}
              disabled={loading}
            />
          )}
          
          <TextInput
            label="Пароль"
            value={password}
            onChangeText={setPassword}
            mode="outlined"
            style={styles.input}
            secureTextEntry
            disabled={loading}
          />
          
          {!isLogin && (
            <View style={styles.inviteCodeContainer}>
              <TextInput
                label="Код приглашения (опционально)"
                value={inviteCode}
                onChangeText={setInviteCode}
                mode="outlined"
                style={styles.inviteInput}
                disabled={loading}
              />
              <IconButton
                icon="qrcode-scan"
                size={28}
                onPress={() => setShowQRScanner(true)}
                disabled={loading}
                style={styles.qrButton}
              />
            </View>
          )}
          
          {error && (
            <Text style={styles.error}>{error}</Text>
          )}
          
          <Button
            mode="contained"
            onPress={handleSubmit}
            style={styles.button}
            loading={loading}
            disabled={loading || !phoneNumber || !password || (!isLogin && !displayName)}
          >
            {isLogin ? 'Войти' : 'Зарегистрироваться'}
          </Button>
          
          <Button
            mode="text"
            onPress={toggleMode}
            disabled={loading}
          >
            {isLogin ? 'Нет аккаунта? Зарегистрироваться' : 'Уже есть аккаунт? Войти'}
          </Button>
        </Surface>

        <Modal
          visible={showQRScanner}
          animationType="slide"
          onRequestClose={() => setShowQRScanner(false)}
        >
          <QRScanner
            onScan={handleQRScan}
            onClose={() => setShowQRScanner(false)}
          />
        </Modal>
      </ScrollView>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#E3F2FD',
  },
  scrollContent: {
    flexGrow: 1,
    justifyContent: 'center',
    padding: 20,
  },
  surface: {
    padding: 24,
    borderRadius: 12,
    backgroundColor: 'white',
  },
  title: {
    textAlign: 'center',
    marginBottom: 24,
    fontWeight: 'bold',
  },
  input: {
    marginBottom: 16,
  },
  inviteCodeContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  inviteInput: {
    flex: 1,
    marginBottom: 0,
  },
  qrButton: {
    marginLeft: 8,
  },
  button: {
    marginTop: 8,
    marginBottom: 16,
  },
  error: {
    color: '#F44336',
    textAlign: 'center',
    marginBottom: 16,
  },
});

export default AuthScreen;

