import React, { useEffect, useState, useRef } from 'react';
import { View, FlatList, StyleSheet, KeyboardAvoidingView, Platform, ImageBackground } from 'react-native';
import { TextInput, IconButton, Surface, Text } from 'react-native-paper';
import { RouteProp, useRoute } from '@react-navigation/native';
import { useAppDispatch, useAppSelector } from '../store';
import { fetchMessages, sendTextMessage, addMessage, addOptimisticMessage } from '../store/slices/messagesSlice';
import { clearUnreadCount, setActiveChat } from '../store/slices/chatsSlice';
import { formatMessageDate } from '../utils/helpers';
import { RootStackParamList, Message, MessageType, MessageStatus } from '../types';
import { generateUUID } from '../utils/helpers';

type ChatScreenRouteProp = RouteProp<RootStackParamList, 'Chat'>;

const ChatScreen: React.FC = () => {
  const route = useRoute<ChatScreenRouteProp>();
  const { chatId } = route.params;
  const dispatch = useAppDispatch();
  
  const { token, user } = useAppSelector((state) => state.auth);
  const messages = useAppSelector((state) => state.messages.byChat[chatId] || []);
  const loading = useAppSelector((state) => state.messages.loading[chatId]);
  
  const [inputText, setInputText] = useState('');
  const flatListRef = useRef<FlatList>(null);

  useEffect(() => {
    if (token) {
      dispatch(fetchMessages({ token, chatId }));
      dispatch(setActiveChat(chatId));
      dispatch(clearUnreadCount(chatId));
    }

    return () => {
      dispatch(setActiveChat(null));
    };
  }, [dispatch, token, chatId]);

  const handleSend = () => {
    if (!inputText.trim() || !token || !user) return;

    const optimisticMessage: Message = {
      id: '',
      localId: generateUUID(),
      chatId,
      senderId: user.id,
      senderName: user.displayName,
      type: MessageType.Text,
      content: inputText.trim(),
      status: MessageStatus.Sending,
      createdAt: new Date().toISOString(),
      isLocalOnly: true,
    };

    dispatch(addOptimisticMessage(optimisticMessage));
    dispatch(sendTextMessage({ token, chatId, content: inputText.trim() }));
    
    setInputText('');
  };

  const renderMessage = ({ item }: { item: Message }) => {
    const isOwn = user && item.senderId === user.id;
    
    return (
      <View style={[styles.messageContainer, isOwn ? styles.ownMessage : styles.otherMessage]}>
        <Surface style={[styles.bubble, isOwn ? styles.ownBubble : styles.otherBubble]} elevation={1}>
          {!isOwn && (
            <Text style={styles.senderName}>{item.senderName}</Text>
          )}
          <Text style={styles.messageText}>{item.content}</Text>
          <Text style={styles.timestamp}>{formatMessageDate(item.createdAt)}</Text>
        </Surface>
      </View>
    );
  };

  return (
    <KeyboardAvoidingView 
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={Platform.OS === 'ios' ? 90 : 0}
    >
      <ImageBackground 
        source={require('../../assets/chat_background.png')}
        style={styles.backgroundImage}
        resizeMode="cover"
      >
        <FlatList
          ref={flatListRef}
          data={messages}
          keyExtractor={(item) => item.localId || item.id}
          renderItem={renderMessage}
          onContentSizeChange={() => flatListRef.current?.scrollToEnd()}
          style={styles.list}
        />
      </ImageBackground>
      
      <View style={styles.inputContainer}>
        <TextInput
          value={inputText}
          onChangeText={setInputText}
          placeholder="Сообщение..."
          mode="outlined"
          style={styles.input}
          multiline
          maxLength={1000}
        />
        <IconButton
          icon="send"
          size={24}
          onPress={handleSend}
          disabled={!inputText.trim()}
        />
      </View>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  backgroundImage: {
    flex: 1,
  },
  list: {
    flex: 1,
    padding: 8,
    backgroundColor: 'transparent',
  },
  messageContainer: {
    marginVertical: 4,
    maxWidth: '80%',
  },
  ownMessage: {
    alignSelf: 'flex-end',
  },
  otherMessage: {
    alignSelf: 'flex-start',
  },
  bubble: {
    padding: 12,
    borderRadius: 16,
  },
  ownBubble: {
    backgroundColor: '#E3F2FD',
  },
  otherBubble: {
    backgroundColor: '#FFFFFF',
  },
  senderName: {
    fontSize: 12,
    fontWeight: 'bold',
    marginBottom: 4,
    color: '#2196F3',
  },
  messageText: {
    fontSize: 16,
  },
  timestamp: {
    fontSize: 10,
    color: '#757575',
    marginTop: 4,
    alignSelf: 'flex-end',
  },
  inputContainer: {
    flexDirection: 'row',
    padding: 8,
    alignItems: 'flex-end',
    backgroundColor: 'white',
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  input: {
    flex: 1,
    marginRight: 8,
  },
});

export default ChatScreen;

