//src/main.jsx
import React from 'react';
import ReactDOM from 'react-dom/client'; // импорт из 'react-dom/client'
import App from './App.jsx';
import './index.css';
import './style.css';
import { UserProvider } from './context/UserContext';

// Найдите контейнер, в который вы хотите рендерить приложение
const container = document.getElementById('root');

// Создайте корень
const root = ReactDOM.createRoot(container);

// Теперь используйте root.render для рендеринга приложения
root.render(
    //из-за StrictMode методы поиска контроллера вызывались дважды.
    //<React.StrictMode>
        <UserProvider>
            <App />
        </UserProvider>
    //</React.StrictMode>
);
