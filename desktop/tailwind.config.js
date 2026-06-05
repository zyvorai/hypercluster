/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        glass: {
          bg: '#0B0B0F',
          panel: 'rgba(255,255,255,0.06)',
          border: 'rgba(255,255,255,0.12)',
          accent: '#f97316',
          muted: 'rgba(255,255,255,0.55)',
        },
        zyvor: {
          orange: '#f97316',
          'orange-light': '#fb923c',
        },
      },
      borderRadius: {
        glass: '22px',
        'glass-lg': '28px',
      },
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          'SF Pro Display',
          'SF Pro Text',
          'system-ui',
          'sans-serif',
        ],
      },
    },
  },
  plugins: [],
}
