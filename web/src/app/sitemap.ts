import type { MetadataRoute } from 'next';

// Publish only genuinely public, reviewed pages. Never index a learner's
// private learning journey, unverified catalog entries, or profile routes.
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: 'https://www.lyoai.app/',
      changeFrequency: 'weekly',
      priority: 1,
    },
  ];
}
