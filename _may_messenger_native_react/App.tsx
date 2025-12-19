import React from 'react';
import { Provider as PaperProvider } from 'react-native-paper';
import { Provider as ReduxProvider } from 'react-redux';
import { store } from './src/store';
import { lightTheme } from './src/theme';
import RootNavigator from './src/navigation/RootNavigator';
import ErrorBoundary from './src/components/ErrorBoundary';

const App: React.FC = () => {
  return (
    <ErrorBoundary>
      <ReduxProvider store={store}>
        <PaperProvider theme={lightTheme}>
          <RootNavigator />
        </PaperProvider>
      </ReduxProvider>
    </ErrorBoundary>
  );
};

export default App;
