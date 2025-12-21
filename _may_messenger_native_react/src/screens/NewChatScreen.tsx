import React, { useState } from 'react';
import { View, StyleSheet, FlatList, TouchableOpacity } from 'react-native';
import { TextInput, List, Text, ActivityIndicator } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { useAppDispatch, useAppSelector } from '../store';
import { createChat } from '../store/slices/chatsSlice';
import { RootStackParamList } from '../types';
import Avatar from '../components/Avatar';

type NavigationProp = StackNavigationProp<RootStackParamList>;

interface RegisteredContact {
  userId: string;
  displayName: string;
}

const NewChatScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const dispatch = useAppDispatch();
  const { token } = useAppSelector((state) => state.auth);
  const contactsMapping = useAppSelector((state) => state.contacts.mapping);
  
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Convert contacts mapping to array of RegisteredContact
  const registeredContacts: RegisteredContact[] = Object.entries(contactsMapping).map(([userId, displayName]) => ({
    userId,
    displayName,
  }));

  // Filter contacts based on search query
  const filteredContacts = registeredContacts.filter(contact =>
    contact.displayName.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const handleCreateChat = async (userId: string, displayName: string) => {
    if (!token) return;

    setLoading(true);
    setError('');

    try {
      const result = await dispatch(createChat({ 
        token, 
        participantIds: [userId],
      })).unwrap();
      
      navigation.navigate('Chat', { 
        chatId: result.id, 
        chatTitle: displayName 
      });
    } catch (err: any) {
      setError(err || 'Ошибка создания чата');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <TextInput
        label="Поиск"
        value={searchQuery}
        onChangeText={setSearchQuery}
        mode="outlined"
        style={styles.searchInput}
        left={<TextInput.Icon icon="magnify" />}
      />

      {error && (
        <Text style={styles.error}>{error}</Text>
      )}

      {registeredContacts.length === 0 ? (
        <View style={styles.centerContainer}>
          <Text style={styles.emptyText}>
            Нет зарегистрированных контактов.{'\n'}
            Синхронизируйте контакты в настройках.
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredContacts}
          keyExtractor={(item) => item.userId}
          renderItem={({ item }) => (
            <TouchableOpacity onPress={() => handleCreateChat(item.userId, item.displayName)}>
              <List.Item
                title={item.displayName}
                description="Начать диалог"
                left={() => <Avatar name={item.displayName} size={48} />}
                right={() => <List.Icon icon="chevron-right" />}
              />
            </TouchableOpacity>
          )}
          ListEmptyComponent={
            <View style={styles.centerContainer}>
              <Text style={styles.emptyText}>
                Контакты не найдены
              </Text>
            </View>
          }
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
  searchInput: {
    margin: 16,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  emptyText: {
    fontSize: 16,
    color: '#757575',
    textAlign: 'center',
  },
  error: {
    color: '#F44336',
    marginHorizontal: 16,
    marginBottom: 8,
  },
});

export default NewChatScreen;
