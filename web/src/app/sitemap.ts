import type { MetadataRoute } from 'next';

// Publish only genuinely public, reviewed pages. Never index a learner's
// private learning journey, unverified catalog entries, or profile routes.
// The legal pages are public on purpose: the app stores and the iPhone app
// link to them, and reviewers open them without an account.
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: 'https://www.lyoai.app/',
      changeFrequency: 'weekly',
      priority: 1,
    },
    { url: 'https://www.lyoai.app/privacy', changeFrequency: 'monthly', priority: 0.3 },
    { url: 'https://www.lyoai.app/terms', changeFrequency: 'monthly', priority: 0.3 },
    { url: 'https://www.lyoai.app/support', changeFrequency: 'monthly', priority: 0.3 },
  ];
}
