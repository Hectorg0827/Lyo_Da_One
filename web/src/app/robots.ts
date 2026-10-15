import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: [
        '/api/', '/auth/', '/chat/', '/classroom/', '/test-prep/',
        '/profile/', '/settings/', '/notifications/', '/messages/',
        '/community/', '/clips/', '/discover/',
      ],
    },
    sitemap: 'https://www.lyoai.app/sitemap.xml',
    host: 'https://www.lyoai.app',
  };
}
