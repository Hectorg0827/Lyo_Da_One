import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { Toaster } from 'react-hot-toast';
import './globals.css';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

export const metadata: Metadata = {
  title: {
    default: 'LYO Da ONE',
    template: '%s | LYO Da ONE',
  },
  description: 'Your AI-powered learning companion',
  keywords: ['AI learning', 'education', 'courses', 'personalized learning', 'LYO'],
  authors: [{ name: 'LYO Team' }],
  creator: 'LYO',
  openGraph: {
    type: 'website',
    locale: 'en_US',
    title: 'LYO Da ONE',
    description: 'Your AI-powered learning companion',
    siteName: 'LYO Da ONE',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'LYO Da ONE',
    description: 'Your AI-powered learning companion',
  },
  robots: {
    index: true,
    follow: true,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`dark ${inter.variable}`} suppressHydrationWarning>
      <body
        className="antialiased min-h-screen"
        style={{ backgroundColor: 'var(--background)', color: 'var(--text-primary)' }}
      >
        <div className="dark">
          {children}
        </div>

        <Toaster
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: {
              background: 'var(--surface)',
              color: 'var(--text-primary)',
              border: '1px solid var(--border)',
              borderRadius: '12px',
              fontSize: '14px',
            },
            success: {
              iconTheme: {
                primary: '#22c55e',
                secondary: 'var(--surface)',
              },
            },
            error: {
              iconTheme: {
                primary: '#ef4444',
                secondary: 'var(--surface)',
              },
            },
          }}
        />
      </body>
    </html>
  );
}
