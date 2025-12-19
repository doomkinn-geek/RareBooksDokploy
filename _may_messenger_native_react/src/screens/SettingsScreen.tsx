import React from 'react';
import { View, StyleSheet } from 'react-native';
import { List, Button, Divider, Text } from 'react-native-paper';
import { useAppDispatch, useAppSelector } from '../store';
import { logoutUser } from '../store/slices/authSlice';

const SettingsScreen: React.FC = () => {
  const dispatch = useAppDispatch();
  const { user } = useAppSelector((state) => state.auth);

  const handleLogout = () => {
    dispatch(logoutUser());
  };

  return (
    <View style={styles.container}>
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
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
  },
  buttonContainer: {
    padding: 20,
    marginTop: 'auto',
  },
  logoutButton: {
    marginTop: 8,
  },
});

export default SettingsScreen;

