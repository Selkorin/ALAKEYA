import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Renderer build. Output is loaded by Electron in production
// (electron/main.js → loadFile('../dist/index.html')).
export default defineConfig({
  root: '.',
  base: './',
  plugins: [react()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    port: 5173,
    strictPort: true,
  },
});
