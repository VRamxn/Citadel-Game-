import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// base "./" so the built site works from any path (GitHub Pages serves it under /<repo>/).
export default defineConfig({
  base: "./",
  plugins: [react()],
  server: { fs: { allow: [".."] } },
});
