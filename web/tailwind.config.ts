import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: { 950: "#07060b", 900: "#0b0a12", 850: "#0f0d18", 800: "#14111f", 700: "#1b1729", 600: "#262038" },
        violet: { 300: "#c4b5fd", 400: "#a78bfa", 500: "#8b5cf6", 600: "#7c3aed", 700: "#6d28d9" },
        lav: { 100: "#ede9fe", 200: "#ddd6fe", 300: "#c4b5fd" },
        line: "rgba(167,139,250,0.14)",
      },
      fontFamily: {
        sans: ["Inter", "ui-sans-serif", "system-ui", "-apple-system", "Segoe UI", "Roboto", "sans-serif"],
        mono: ["ui-monospace", "SFMono-Regular", "Menlo", "Consolas", "monospace"],
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(167,139,250,0.18), 0 8px 40px -12px rgba(139,92,246,0.35)",
        card: "0 1px 0 rgba(255,255,255,0.03) inset, 0 20px 50px -30px rgba(0,0,0,0.8)",
      },
      keyframes: {
        rise: { from: { opacity: "0", transform: "translateY(8px)" }, to: { opacity: "1", transform: "none" } },
      },
      animation: { rise: "rise 0.5s ease-out both" },
    },
  },
  plugins: [],
};
export default config;
