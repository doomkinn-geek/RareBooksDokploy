// vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

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
    }
});
