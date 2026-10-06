import { redirect } from 'next/navigation';

/**
 * `/clips` was a second reel on the same clips API as Discover.
 *
 * Discover is what the product actually points at — the mobile nav, the
 * search bar, the empty course stack — while this page sat in the desktop
 * sidebar alone. Keeping both split the feed in two: commenting and posting
 * worked here, watching and searching worked there, and no phone could reach
 * this one at all.
 *
 * Both now live on Discover. This stays as a redirect rather than a deletion
 * because links to `/clips?clip=<id>` have already been shared, and a shared
 * clip that 404s is a worse outcome than a tidy route list. Query parameters
 * carry over so those links land on the clip they named.
 */
export default function ClipsPage({
  searchParams,
}: {
  searchParams: Record<string, string | string[] | undefined>;
}) {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(searchParams)) {
    if (typeof value === 'string') query.set(key, value);
    else if (Array.isArray(value) && value[0]) query.set(key, value[0]);
  }
  const suffix = query.toString();
  redirect(suffix ? `/discover?${suffix}` : '/discover');
}
