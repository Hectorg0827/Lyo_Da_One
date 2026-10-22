// www.lyoai.app is the site's canonical host (layout.tsx metadataBase,
// robots.ts, sitemap.ts). The bare domain is served by a separate deployment
// that has fallen behind this one, so it only forwards, keeping the path and
// query: links the apps and the API build on https://lyoai.app keep working.
const CANONICAL_ORIGIN = 'https://www.lyoai.app';

/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '**' },
    ],
  },
  async redirects() {
    return [
      {
        source: '/:path*',
        has: [{ type: 'host', value: 'lyoai.app' }],
        destination: `${CANONICAL_ORIGIN}/:path*`,
        permanent: true,
      },
    ];
  },
};

module.exports = nextConfig;
