import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: '/web/',
  
  server: {
    host: true,
    port: 3000,
  },

  // Production optimizations
  build: {
    // Output directory
    outDir: 'dist',
    
    // Generate sourcemaps for debugging (can disable in production)
    sourcemap: false,
    
    // Minification using esbuild (faster and built-in with Vite)
    minify: 'esbuild',
    
    // Chunk splitting strategy for better caching
    rollupOptions: {
      output: {
        manualChunks: {
          // React and related libraries
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          // SignalR
          'signalr': ['@microsoft/signalr'],
          // UI libraries
          'ui-vendor': ['lucide-react', 'qrcode.react'],
          // State management
          'state': ['zustand'],
          // HTTP client
          'http': ['axios'],
        },
        // Better file names for caching
        chunkFileNames: 'assets/[name]-[hash].js',
        entryFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash].[ext]',
      },
    },
    
    // Asset optimization
    assetsInlineLimit: 4096, // 4kb - inline smaller assets as base64
    
    // Performance: warn if chunk size > 500kb
    chunkSizeWarningLimit: 500,
    
    // CSS code splitting
    cssCodeSplit: true,
  },

  // Dependency pre-bundling optimization
  optimizeDeps: {
    include: [
      'react',
      'react-dom',
      'react-router-dom',
      '@microsoft/signalr',
      'axios',
      'zustand',
    ],
  },

  // Preview server configuration
  preview: {
    port: 3000,
    host: true,
  },
})
