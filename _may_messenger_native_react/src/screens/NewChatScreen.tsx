import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { TextInput, Button, Text } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { useAppDispatch, useAppSelector } from '../store';
import { createChat } from '../store/slices/chatsSlice';
import { RootStackParamList } from '../types';

type NavigationProp = StackNavigationProp<RootStackParamList>;

const NewChatScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const dispatch = useAppDispatch();
  const { token } = useAppSelector((state) => state.auth);
  
  const [userId, setUserId] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleCreate = async () => {
    if (!userId.trim() || !token) return;

    setLoading(true);
    setError('');

    try {
      const result = await dispatch(createChat({ 
        token, 
        participantIds: [userId.trim()],
      })).unwrap();
      
      navigation.navigate('Chat', { 
        chatId: result.id, 
        chatTitle: result.title 
      });
    } catch (err: any) {
      setError(err || 'Ошибка создания чата');
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <Text variant="titleMedium" style={styles.label}>
        Введите ID пользователя
      </Text>
      
      <TextInput
        label="User ID"
        value={userId}
        onChangeText={setUserId}
        mode="outlined"
        style={styles.input}
        disabled={loading}
      />
      
      {error && (
        <Text style={styles.error}>{error}</Text>
      )}
      
      <Button
        mode="contained"
        onPress={handleCreate}
        loading={loading}
        disabled={loading || !userId.trim()}
        style={styles.button}
      >
        Создать чат
      </Button>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: 'white',
  },
  label: {
    marginBottom: 16,
  },
  input: {
    marginBottom: 16,
  },
  button: {
    marginTop: 8,
  },
  error: {
    color: '#F44336',
    marginBottom: 16,
  },
});

export default NewChatScreen;

