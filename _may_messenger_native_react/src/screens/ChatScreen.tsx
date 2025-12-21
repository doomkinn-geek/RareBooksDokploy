import React, { useEffect, useState, useRef } from 'react';
import { View, FlatList, StyleSheet, KeyboardAvoidingView, Platform, ActivityIndicator, Image } from 'react-native';
import { TextInput, IconButton, Surface, Text } from 'react-native-paper';
import LinearGradient from 'react-native-linear-gradient';
import { RouteProp, useRoute } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import { useAppDispatch, useAppSelector } from '../store';
import { fetchMessages, sendTextMessage, sendAudioMessage, sendImageMessage, addMessage, addOptimisticMessage, updateMessageStatus, markMessagesAsRead } from '../store/slices/messagesSlice';
import { clearUnreadCount, setActiveChat } from '../store/slices/chatsSlice';
import { formatMessageDate } from '../utils/helpers';
import { RootStackParamList, Message, MessageType, MessageStatus } from '../types';
import { generateUUID } from '../utils/helpers';
import AnimatedMessageBubble from '../components/AnimatedMessageBubble';
import AudioRecorderExpo from '../components/AudioRecorderExpo';
import AudioPlayerExpo from '../components/AudioPlayerExpo';
import { signalrService } from '../services/signalrService';
import { imageService } from '../services/imageService';

type ChatScreenRouteProp = RouteProp<RootStackParamList, 'Chat'>;

const ChatScreen: React.FC = () => {
  const route = useRoute<ChatScreenRouteProp>();
  const { chatId } = route.params;
  const dispatch = useAppDispatch();
  
  const { token, user } = useAppSelector((state) => state.auth);
  const messages = useAppSelector((state) => state.messages.byChat[chatId] || []);
  const loading = useAppSelector((state) => state.messages.loading[chatId]);
  
  const [inputText, setInputText] = useState('');
  const [isRecordingAudio, setIsRecordingAudio] = useState(false);
  const flatListRef = useRef<FlatList>(null);

  useEffect(() => {
    if (token) {
      dispatch(fetchMessages({ token, chatId }));
      dispatch(setActiveChat(chatId));
      dispatch(clearUnreadCount(chatId));
      
      // Join SignalR chat
      signalrService.joinChat(chatId);
    }

    // Setup SignalR listeners
    signalrService.onMessageStatusUpdated((messageId, status) => {
      dispatch(updateMessageStatus({ messageId, status }));
    });

    signalrService.onReceiveMessage((message) => {
      if (message.chatId === chatId) {
        dispatch(addMessage(message));
        
        // Auto-mark as read if chat is active
        if (user && message.senderId !== user.id) {
          signalrService.markMessageAsRead(message.id, chatId);
        }
      }
    });

    return () => {
      dispatch(setActiveChat(null));
      signalrService.leaveChat(chatId);
    };
  }, [dispatch, token, chatId, user]);

  // Mark existing unread messages as read when screen opens
  useEffect(() => {
    if (token && user && messages.length > 0) {
      const unreadMessageIds = messages
        .filter(m => m.senderId !== user.id && m.status !== MessageStatus.Read)
        .map(m => m.id)
        .filter(id => id); // Filter out empty IDs

      if (unreadMessageIds.length > 0) {
        dispatch(markMessagesAsRead({ token, messageIds: unreadMessageIds }));
        
        // Also mark via SignalR
        unreadMessageIds.forEach(messageId => {
          signalrService.markMessageAsRead(messageId, chatId);
        });
      }
    }
  }, [messages.length, token, user, chatId, dispatch]);

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

  const handleStartRecording = () => {
    setIsRecordingAudio(true);
  };

  const handleSendAudio = (audioUri: string) => {
    if (!token || !user) return;

    const optimisticMessage: Message = {
      id: '',
      localId: generateUUID(),
      chatId,
      senderId: user.id,
      senderName: user.displayName,
      type: MessageType.Audio,
      content: '🎤 Аудио сообщение',
      filePath: audioUri,
      status: MessageStatus.Sending,
      createdAt: new Date().toISOString(),
      isLocalOnly: true,
    };

    dispatch(addOptimisticMessage(optimisticMessage));
    dispatch(sendAudioMessage({ token, chatId, audioUri }));
    
    setIsRecordingAudio(false);
  };

  const handleCancelRecording = () => {
    setIsRecordingAudio(false);
  };

  const handleCapturePhoto = async () => {
    try {
      const result = await imageService.capturePhoto();
      if (result && token && user) {
        const optimisticMessage: Message = {
          id: '',
          localId: generateUUID(),
          chatId,
          senderId: user.id,
          senderName: user.displayName,
          type: MessageType.Image,
          content: '📷 Изображение',
          filePath: result.uri,
          status: MessageStatus.Sending,
          createdAt: new Date().toISOString(),
          isLocalOnly: true,
        };

        dispatch(addOptimisticMessage(optimisticMessage));
        dispatch(sendImageMessage({ 
          token, 
          chatId, 
          imageUri: result.uri, 
          imageType: result.type, 
          imageName: result.name 
        }));
      }
    } catch (error) {
      console.error('Failed to capture photo:', error);
    }
  };

  const handlePickPhoto = async () => {
    try {
      const result = await imageService.pickPhoto();
      if (result && token && user) {
        const optimisticMessage: Message = {
          id: '',
          localId: generateUUID(),
          chatId,
          senderId: user.id,
          senderName: user.displayName,
          type: MessageType.Image,
          content: '📷 Изображение',
          filePath: result.uri,
          status: MessageStatus.Sending,
          createdAt: new Date().toISOString(),
          isLocalOnly: true,
        };

        dispatch(addOptimisticMessage(optimisticMessage));
        dispatch(sendImageMessage({ 
          token, 
          chatId, 
          imageUri: result.uri, 
          imageType: result.type, 
          imageName: result.name 
        }));
      }
    } catch (error) {
      console.error('Failed to pick photo:', error);
    }
  };

  const renderStatusIcon = (status: MessageStatus) => {
    switch (status) {
      case MessageStatus.Sending:
        return <ActivityIndicator size="small" color="#757575" style={styles.statusIcon} />;
      case MessageStatus.Sent:
        return <Icon name="check" size={14} color="#757575" style={styles.statusIcon} />;
      case MessageStatus.Delivered:
        return <Icon name="check-all" size={14} color="#757575" style={styles.statusIcon} />;
      case MessageStatus.Read:
        return <Icon name="check-all" size={14} color="#4CAF50" style={styles.statusIcon} />;
      case MessageStatus.Failed:
        return <Icon name="alert-circle" size={14} color="#F44336" style={styles.statusIcon} />;
      default:
        return null;
    }
  };

  const renderMessage = ({ item }: { item: Message }) => {
    const isOwn = user && item.senderId === user.id;
    
    return (
      <AnimatedMessageBubble isOwnMessage={isOwn}>
        <View style={[styles.messageContainer, isOwn ? styles.ownMessage : styles.otherMessage]}>
          <Surface style={[styles.bubble, isOwn ? styles.ownBubble : styles.otherBubble]} elevation={1}>
            {!isOwn && (
              <Text style={styles.senderName}>{item.senderName}</Text>
            )}
            {item.type === MessageType.Text && (
              <Text style={styles.messageText}>{item.content}</Text>
            )}
            {item.type === MessageType.Audio && (
              <AudioPlayerExpo audioUrl={item.filePath || item.content || ''} />
            )}
            {item.type === MessageType.Image && (
              <View style={styles.imageContainer}>
                <Image 
                  source={{ uri: item.filePath || item.content }} 
                  style={styles.messageImage}
                  resizeMode="cover"
                />
              </View>
            )}
            <View style={styles.messageFooter}>
              <Text style={styles.timestamp}>{formatMessageDate(item.createdAt)}</Text>
              {isOwn && renderStatusIcon(item.status)}
            </View>
          </Surface>
        </View>
      </AnimatedMessageBubble>
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
      
      {isRecordingAudio ? (
        <AudioRecorderExpo 
          onSend={handleSendAudio} 
          onCancel={handleCancelRecording} 
        />
      ) : (
        <View style={styles.inputContainer}>
          <IconButton
            icon="camera"
            size={28}
            iconColor="#757575"
            onPress={handleCapturePhoto}
            style={styles.attachButton}
          />
          <IconButton
            icon="image"
            size={28}
            iconColor="#757575"
            onPress={handlePickPhoto}
            style={styles.attachButton}
          />
          <IconButton
            icon="microphone"
            size={28}
            iconColor="#757575"
            onPress={handleStartRecording}
            style={styles.attachButton}
          />
          <TextInput
            value={inputText}
            onChangeText={setInputText}
            placeholder="Сообщение..."
            mode="outlined"
            style={styles.input}
            multiline
            maxLength={1000}
            onSubmitEditing={handleSend}
          />
          <IconButton
            icon="send"
            size={28}
            iconColor={inputText.trim() ? '#2196F3' : '#9E9E9E'}
            onPress={handleSend}
            disabled={!inputText.trim()}
            style={styles.sendButton}
          />
        </View>
      )}
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
    maxWidth: '100%',
  },
  ownBubble: {
    backgroundColor: '#DCF8C6',
    borderBottomRightRadius: 4,
  },
  otherBubble: {
    backgroundColor: '#FFFFFF',
    borderBottomLeftRadius: 4,
  },
  senderName: {
    fontSize: 12,
    fontWeight: 'bold',
    marginBottom: 4,
    color: '#2196F3',
  },
  messageText: {
    fontSize: 16,
    lineHeight: 22,
    color: '#000000',
  },
  messageFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    marginTop: 4,
  },
  timestamp: {
    fontSize: 10,
    color: '#757575',
  },
  statusIcon: {
    marginLeft: 4,
  },
  inputContainer: {
    flexDirection: 'row',
    padding: 8,
    alignItems: 'flex-end',
    backgroundColor: '#F5F5F5',
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  input: {
    flex: 1,
    marginRight: 8,
    maxHeight: 100,
    backgroundColor: 'white',
  },
  sendButton: {
    margin: 0,
  },
  attachButton: {
    margin: 0,
    marginRight: 4,
  },
  imageContainer: {
    marginVertical: 4,
  },
  messageImage: {
    width: 200,
    height: 200,
    borderRadius: 8,
  },
});

export default ChatScreen;

