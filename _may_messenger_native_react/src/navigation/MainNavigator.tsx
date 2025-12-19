import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import ChatsListScreen from '../screens/ChatsListScreen';
import SettingsScreen from '../screens/SettingsScreen';
import { MainTabParamList } from '../types';

const Tab = createBottomTabNavigator<MainTabParamList>();

const MainNavigator: React.FC = () => {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string;

          if (route.name === 'Chats') {
            iconName = focused ? 'message-text' : 'message-text-outline';
          } else {
            iconName = focused ? 'cog' : 'cog-outline';
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#2196F3',
        tabBarInactiveTintColor: '#757575',
      })}
    >
      <Tab.Screen 
        name="Chats" 
        component={ChatsListScreen}
        options={{ title: 'Чаты' }}
      />
      <Tab.Screen 
        name="Settings" 
        component={SettingsScreen}
        options={{ title: 'Настройки' }}
      />
    </Tab.Navigator>
  );
};

export default MainNavigator;

