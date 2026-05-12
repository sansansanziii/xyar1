import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 9000,
    host: '0.0.0.0', // 允许外部访问
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      'xy.zhinianboke.com',
      'xy-back.zhinianboke.com'
    ],
    proxy: {
      // 所有 API 请求统一代理到后端（含WebSocket升级）
      '/api': {
        target: 'http://localhost:8089',
        changeOrigin: true,
        ws: true,
      },
      // 静态文件代理到后端（包含上传的图片）
      '/static': {
        target: 'http://localhost:8089',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    assetsDir: 'static',
  },
})
