/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        glass: {
          bg: '#050508',
          panel: 'rgba(255,255,255,0.06)',
          border: 'rgba(255,255,255,0.1)',
          accent: '#f0583a',
          'accent-light': '#f47a60',
          purple: '#a78bfa',
          muted: 'rgba(255,255,255,0.58)',
        },
        zyvor: {
          orange: '#f0583a',
          'orange-light': '#ff8a3d',
          purple: '#a78bfa',
          indigo: '#6366f1',
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
          'Segoe UI',
          'system-ui',
          'sans-serif',
        ],
      },
      boxShadow: {
        'zyvor-glow': '0 4px 24px rgba(240, 88, 58, 0.22)',
        'zyvor-card': '0 16px 50px rgba(0, 0, 0, 0.35)',
      },
    },
  },
  plugins: [],
}
