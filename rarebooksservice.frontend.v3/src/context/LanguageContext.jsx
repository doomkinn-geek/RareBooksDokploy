import React, { createContext, useState, useEffect } from 'react';

// Создаем контекст для языка
export const LanguageContext = createContext();

export const LanguageProvider = ({ children }) => {
    // Пытаемся получить сохраненный язык из localStorage или используем 'RU' по умолчанию
    const [language, setLanguage] = useState(() => {
        const savedLanguage = localStorage.getItem('language');
        return savedLanguage || 'RU';
    });

    // Сохраняем язык в localStorage при его изменении
    useEffect(() => {
        localStorage.setItem('language', language);
    }, [language]);

    // Предоставляем текущий язык и функцию для его изменения через контекст
    return (
        <LanguageContext.Provider value={{ language, setLanguage }}>
            {children}
        </LanguageContext.Provider>
    );
}; 