//src/main.jsx
import React from 'react';
import ReactDOM from 'react-dom/client'; // ������  'react-dom/client'
import App from './App.jsx';
import './index.css';
import './style.css';
import { UserProvider } from './context/UserContext';
import { ThemeProvider } from '@mui/material/styles';
import theme from './theme';
import { BrowserRouter } from 'react-router-dom';
import { LanguageProvider } from './context/LanguageContext';
import CssBaseline from '@mui/material/CssBaseline';

//  ,     
const container = document.getElementById('root');

// �������� ������
const root = ReactDOM.createRoot(container);

// Добавляем тег viewport для правильного масштабирования на мобильных устройствах
const viewport = document.createElement('meta');
viewport.name = 'viewport';
viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
document.head.appendChild(viewport);

//   root.render   
root.render(
    //- StrictMode     .
    <React.StrictMode>
        <ThemeProvider theme={theme}>
            <CssBaseline />
            <BrowserRouter>
                <LanguageProvider>
                    <UserProvider>
                        <App />
                    </UserProvider>
                </LanguageProvider>
            </BrowserRouter>
        </ThemeProvider>
    </React.StrictMode>
);
