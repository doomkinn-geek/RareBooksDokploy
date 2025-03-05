// vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'fs';
import path from 'path';

export default defineConfig({
    plugins: [react()],
    build: {
        rollupOptions: {
            // Не указываем как external, чтобы библиотека была включена в сборку
        }
    },
    optimizeDeps: {
        include: [
            'js-cookie',
            '@mui/styled-engine',
            'yet-another-react-lightbox', 
            'dompurify'
        ]
    },
    resolve: {
        alias: {
            // Можно добавить алиасы, если нужно
        }
    },
    server: {
        // Настройка прокси для работы с бэкендом по HTTP
        proxy: {
            '/api': {
                target: 'http://localhost:5000', // Адрес бэкенда с HTTP (стандартный порт ASP.NET Core)
                changeOrigin: true,
                rewrite: (path) => path
            }
        }
        // HTTPS настройки отключены для запуска без HTTPS
    }
});
