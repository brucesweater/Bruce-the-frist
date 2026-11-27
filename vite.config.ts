/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';

// `npm run build` produces a normal static site in dist/ (relative paths, so it
// works from any folder, including a GitHub Pages project URL).
// `npm run build:single` inlines everything into one HTML file in dist-single/,
// which is handy for sharing a self-contained preview.
export default defineConfig(({ mode }) => {
  const single = mode === 'single';
  return {
    base: './',
    plugins: [react(), ...(single ? [viteSingleFile()] : [])],
    build: single
      ? { outDir: 'dist-single', assetsInlineLimit: 100_000_000, emptyOutDir: true }
      : {
          outDir: 'dist',
          emptyOutDir: true,
          // The college dataset and React change rarely; separate chunks load in
          // parallel and stay cached when the app code changes.
          chunkSizeWarningLimit: 700,
          rolldownOptions: {
            output: {
              codeSplitting: {
                groups: [
                  { name: 'colleges', test: /src[\\/]data[\\/]colleges\.json/ },
                  { name: 'react', test: /node_modules[\\/](react|react-dom|scheduler)[\\/]/ },
                ],
              },
            },
          },
        },
    test: {
      environment: 'node',
      include: ['src/**/*.test.ts'],
    },
  };
});
