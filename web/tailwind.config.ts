import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  darkMode: 'class',
  theme: {
    extend: {
      // Generated from /design-tokens.json (source of truth: iOS Sources/Core/DesignTokens.swift).
      // Do not hand-edit hex values here; update design-tokens.json and mirror the change.
      colors: {
        lyo: {
          50: '#f0f4ff',
          100: '#dbe4ff',
          200: '#bac8ff',
          300: '#a78bfa', // brand.secondaryLight
          400: '#8b5cf6', // brand.secondary
          500: '#6366f1', // brand.primary
          600: '#4f46e5',
          700: '#4338ca',
          800: '#3730a3',
          900: '#312e81',
        },
        accent: {
          purple: '#8b5cf6', // brand.secondary
          violet: '#a855f7', // iOS glow accent (course card / mascot FAB)
          magenta: '#d946ef', // brand.accentMagenta
          gold: '#d9b24c', // brand.accentGold
          pink: '#ec4899',
          orange: '#ff8c00', // iOS mascot/greeting orange
          teal: '#14b8a6',
          green: '#10b981', // semantic.success
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        // iOS `.rounded` (SF Pro Rounded); ui-rounded on Apple, Nunito elsewhere
        display: ['ui-rounded', 'SF Pro Rounded', 'var(--font-nunito)', 'Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        // DesignTokens.Shadows.glow / accentGlow
        'glow-accent': '0 0 12px rgba(99, 102, 241, 0.4)',
        'glow-purple': '0 0 20px rgba(139, 92, 246, 0.5)',
        'glow-violet': '0 0 18px rgba(168, 85, 247, 0.55)',
        'glow-orange': '0 0 20px rgba(255, 140, 0, 0.5)',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'float': 'float 6s ease-in-out infinite',
        'glow': 'glow 2s ease-in-out infinite alternate',
        'slide-up': 'slideUp 0.3s ease-out',
        'slide-down': 'slideDown 0.3s ease-out',
        'fade-in': 'fadeIn 0.2s ease-out',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-10px)' },
        },
        glow: {
          '0%': { boxShadow: '0 0 5px rgba(92, 124, 250, 0.5)' },
          '100%': { boxShadow: '0 0 20px rgba(92, 124, 250, 0.8)' },
        },
        slideUp: {
          '0%': { transform: 'translateY(10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        slideDown: {
          '0%': { transform: 'translateY(-10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
      },
      backdropBlur: {
        xs: '2px',
      },
    },
  },
  plugins: [],
};

export default config;
