// vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
    plugins: [
        react(),
        VitePWA({
            registerType: 'autoUpdate',
            includeAssets: ['favicon.ico', 'robots.txt', 'apple-touch-icon.png'],
            manifest: {
                name: 'Редкие Книги',
                short_name: 'РедкиеКниги',
                description: 'Сервис по покупке и продаже редких коллекционных книг',
                theme_color: '#E72B3D',
                background_color: '#ffffff',
                display: 'standalone',
                orientation: 'portrait',
                icons: [
                    {
                        src: '/android-chrome-192x192.png',
                        sizes: '192x192',
                        type: 'image/png',
                    },
                    {
                        src: '/android-chrome-512x512.png',
                        sizes: '512x512',
                        type: 'image/png',
                    },
                    {
                        src: '/apple-touch-icon.png',
                        sizes: '180x180',
                        type: 'image/png',
                        purpose: 'apple touch icon',
                    },
                    {
                        src: '/maskable-icon.png',
                        sizes: '512x512',
                        type: 'image/png',
                        purpose: 'maskable',
                    },
                ],
            },
        }),
    ],
    build: {
        rollupOptions: {
            output: {
                manualChunks: {
                    'react-vendor': ['react', 'react-dom'],
                    'mui-vendor': ['@mui/material', '@mui/icons-material'],
                    'router-vendor': ['react-router-dom'],
                },
            },
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
        host: true,
        port: 5173,
    },
    preview: {
        port: 5173,
    },
});
