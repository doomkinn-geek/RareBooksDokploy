import React, { useState } from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { List, Button, Divider, Text } from 'react-native-paper';
import { useAppDispatch, useAppSelector } from '../store';
import { logoutUser } from '../store/slices/authSlice';
import { syncContacts } from '../store/slices/contactsSlice';
import QRInviteDialog from '../components/QRInviteDialog';
import { API_CONFIG } from '../utils/constants';

const SettingsScreen: React.FC = () => {
  const dispatch = useAppDispatch();
  const { user, token } = useAppSelector((state) => state.auth);
  const { synced: contactsSynced, loading: contactsLoading } = useAppSelector((state) => state.contacts);
  
  const [showQRDialog, setShowQRDialog] = useState(false);
  const [inviteCode, setInviteCode] = useState('');
  const [loadingInvite, setLoadingInvite] = useState(false);

  const handleLogout = () => {
    dispatch(logoutUser());
  };

  const handleSyncContacts = () => {
    if (token) {
      dispatch(syncContacts({ token }));
    }
  };

  const handleGenerateInvite = async () => {
    if (!token) {
      Alert.alert('Ошибка', 'Токен не найден. Пожалуйста, войдите снова.');
      return;
    }
    
    setLoadingInvite(true);
    try {
      console.log('Creating invite code...');
      const response = await fetch(`${API_CONFIG.API_URL}/invite/create`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });

      console.log('Response status:', response.status);
      const text = await response.text();
      console.log('Response body:', text);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${text}`);
      }

      const data = JSON.parse(text);
      console.log('Parsed data:', data);
      
      if (!data.code && !data.inviteCode) {
        throw new Error('Код приглашения не найден в ответе сервера');
      }
      
      const code = data.code || data.inviteCode;
      setInviteCode(code);
      setShowQRDialog(true);
    } catch (error: any) {
      console.error('Failed to generate invite:', error);
      Alert.alert('Ошибка', error.message || 'Не удалось создать код приглашения');
    } finally {
      setLoadingInvite(false);
    }
  };

  return (
    <ScrollView style={styles.container}>
      {user && (
        <>
          <List.Section>
            <List.Subheader>Профиль</List.Subheader>
            <List.Item
              title={user.displayName}
              description={user.phoneNumber}
              left={(props) => <List.Icon {...props} icon="account" />}
            />
          </List.Section>
          <Divider />
        </>
      )}

      <List.Section>
        <List.Subheader>Приглашения</List.Subheader>
        <List.Item
          title="Пригласить друга"
          description="Показать QR-код приглашения"
          left={(props) => <List.Icon {...props} icon="qrcode" />}
          onPress={handleGenerateInvite}
          disabled={loadingInvite}
        />
      </List.Section>

      <Divider />

      <List.Section>
        <List.Subheader>Контакты</List.Subheader>
        <List.Item
          title="Синхронизировать контакты"
          description={contactsSynced ? 'Контакты синхронизированы' : 'Обновить список контактов'}
          left={(props) => <List.Icon {...props} icon="contacts" />}
          onPress={handleSyncContacts}
          disabled={contactsLoading}
        />
      </List.Section>

      <Divider />
      
      <View style={styles.buttonContainer}>
        <Button
          mode="contained"
          onPress={handleLogout}
          style={styles.logoutButton}
          buttonColor="#F44336"
        >
          Выйти
        </Button>
      </View>

      <QRInviteDialog
        visible={showQRDialog}
        inviteCode={inviteCode}
        onDismiss={() => setShowQRDialog(false)}
      />
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
  buttonContainer: {
    padding: 20,
    marginTop: 20,
  },
  logoutButton: {
    marginTop: 8,
  },
});

export default SettingsScreen;
