import path from "path"
const __dirname = import.meta.dirname
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

// https://vite.dev/config/
export default defineConfig(({ mode }) => ({
  base: mode === "production" ? "/frontend/" : "/",
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  optimizeDeps: {
    include: ["lodash"],
  },
  build: {
    outDir: path.resolve(__dirname, "../public/frontend"),
    emptyOutDir: true,
    rollupOptions: {
      output: {
        // Prevent recharts/lodash CJS _ namespace from colliding with
        // esbuild-minified local variables also named _
        manualChunks(id) {
          if (id.includes('recharts') || id.includes('lodash') || id.includes('victory-vendor')) {
            return 'recharts-vendor';
          }
        },
      },
    },
  },
  esbuild: {
    // Reserve _ so esbuild never picks it as a minified variable name
    // This prevents collision with lodash's _ namespace in the same scope
    reserveProps: /^_$/,
  },
}))
