// vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [react()],
    build: {
        rollupOptions: {
            external: [
                //'lightbox.js-react', 
                //'dompurify',
                // Убедитесь, что @emotion/react отсутствует здесь
            ]
        }
    },
    optimizeDeps: {
        include: [
            'js-cookie',
            '@mui/styled-engine',
            'lightbox.js-react', 
            //'@emotion/react',  // Оставьте здесь
            //'@emotion/styled',
            'dompurify'
        ]
    }
});
