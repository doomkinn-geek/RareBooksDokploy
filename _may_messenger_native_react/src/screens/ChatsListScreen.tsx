import React, { useEffect } from 'react';
import { View, FlatList, StyleSheet, TouchableOpacity } from 'react-native';
import { FAB, List, Badge, Text, ActivityIndicator } from 'react-native-paper';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { useAppDispatch, useAppSelector } from '../store';
import { fetchChats } from '../store/slices/chatsSlice';
import { formatMessageDate, getMessagePreview } from '../utils/helpers';
import { RootStackParamList } from '../types';

type NavigationProp = StackNavigationProp<RootStackParamList>;

const ChatsListScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const dispatch = useAppDispatch();
  const { list: chats, loading } = useAppSelector((state) => state.chats);
  const { token } = useAppSelector((state) => state.auth);

  useEffect(() => {
    if (token) {
      dispatch(fetchChats(token));
    }
  }, [dispatch, token]);

  const handleChatPress = (chatId: string, title: string) => {
    navigation.navigate('Chat', { chatId, chatTitle: title });
  };

  const handleNewChat = () => {
    navigation.navigate('NewChat');
  };

  if (loading && chats.length === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={chats}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <TouchableOpacity onPress={() => handleChatPress(item.id, item.title)}>
            <List.Item
              title={item.title}
              description={item.lastMessage ? getMessagePreview(item.lastMessage) : 'Нет сообщений'}
              left={(props) => <List.Icon {...props} icon="message-text" />}
              right={() => (
                <View style={styles.rightContainer}>
                  {item.lastMessage && (
                    <Text style={styles.time}>
                      {formatMessageDate(item.lastMessage.createdAt)}
                    </Text>
                  )}
                  {item.unreadCount > 0 && (
                    <Badge style={styles.badge}>{item.unreadCount}</Badge>
                  )}
                </View>
              )}
            />
          </TouchableOpacity>
        )}
        ListEmptyComponent={
          <View style={styles.center}>
            <Text>Нет чатов. Создайте новый!</Text>
          </View>
        }
      />
      <FAB
        style={styles.fab}
        icon="plus"
        onPress={handleNewChat}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  rightContainer: {
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  time: {
    fontSize: 12,
    color: '#757575',
    marginBottom: 4,
  },
  badge: {
    backgroundColor: '#2196F3',
  },
  fab: {
    position: 'absolute',
    right: 16,
    bottom: 16,
    backgroundColor: '#2196F3',
  },
});

export default ChatsListScreen;

