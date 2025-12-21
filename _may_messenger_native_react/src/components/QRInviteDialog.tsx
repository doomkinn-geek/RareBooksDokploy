import React from 'react';
import { View, StyleSheet, Share } from 'react-native';
import { Dialog, Portal, Button, Text } from 'react-native-paper';
import QRCode from 'react-native-qrcode-svg';
import Clipboard from '@react-native-clipboard/clipboard';

interface QRInviteDialogProps {
  visible: boolean;
  inviteCode: string;
  onDismiss: () => void;
}

const QRInviteDialog: React.FC<QRInviteDialogProps> = ({ visible, inviteCode, onDismiss }) => {
  const inviteUrl = `maymessenger://invite?code=${inviteCode}`;

  const handleCopyCode = async () => {
    Clipboard.setString(inviteCode);
    // Could show a snackbar here
  };

  const handleShare = async () => {
    try {
      await Share.share({
        message: `Присоединяйтесь к May Messenger! Код приглашения: ${inviteCode}`,
        url: inviteUrl,
      });
    } catch (error) {
      console.error('Failed to share invite:', error);
    }
  };

  return (
    <Portal>
      <Dialog visible={visible} onDismiss={onDismiss}>
        <Dialog.Title>Пригласить друга</Dialog.Title>
        <Dialog.Content>
          <View style={styles.qrContainer}>
            <QRCode
              value={inviteUrl}
              size={200}
              backgroundColor="white"
              color="black"
            />
          </View>
          <Text style={styles.codeText}>Код: {inviteCode}</Text>
          <Text style={styles.instructionText}>
            Попросите друга отсканировать этот QR-код или введите код вручную
          </Text>
        </Dialog.Content>
        <Dialog.Actions>
          <Button onPress={handleCopyCode}>Копировать код</Button>
          <Button onPress={handleShare}>Поделиться</Button>
          <Button onPress={onDismiss}>Закрыть</Button>
        </Dialog.Actions>
      </Dialog>
    </Portal>
  );
};

const styles = StyleSheet.create({
  qrContainer: {
    alignItems: 'center',
    padding: 20,
    backgroundColor: 'white',
    borderRadius: 8,
    marginBottom: 16,
  },
  codeText: {
    fontSize: 18,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 12,
  },
  instructionText: {
    fontSize: 14,
    textAlign: 'center',
    color: '#757575',
  },
});

export default QRInviteDialog;

