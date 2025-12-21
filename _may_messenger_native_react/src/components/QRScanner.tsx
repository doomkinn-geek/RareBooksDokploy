import React from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { IconButton, Button } from 'react-native-paper';

interface QRScannerProps {
  onScan: (code: string) => void;
  onClose: () => void;
}

const QRScanner: React.FC<QRScannerProps> = ({ onScan, onClose }) => {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerText}>QR сканер</Text>
        <IconButton icon="close" size={32} iconColor="white" onPress={onClose} />
      </View>
      <View style={styles.content}>
        <Text style={styles.messageText}>
          QR сканер временно недоступен.{'\n'}
          Пожалуйста, введите код приглашения вручную.
        </Text>
        <Button mode="contained" onPress={onClose} style={styles.button}>
          Закрыть
        </Button>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'black',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
  },
  headerText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
    flex: 1,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  messageText: {
    color: 'white',
    fontSize: 16,
    textAlign: 'center',
    marginBottom: 24,
    lineHeight: 24,
  },
  button: {
    minWidth: 120,
  },
});

export default QRScanner;
