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
                // ���������, ��� @emotion/react ����������� �����
            ]
        }
    },
    optimizeDeps: {
        include: [
            'js-cookie',
            '@mui/styled-engine',
            'yet-another-react-lightbox', 
            //'@emotion/react',  //  
            //'@emotion/styled',
            'dompurify'
        ]
    }
});
