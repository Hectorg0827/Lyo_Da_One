// Launch containment: false until production community data, map and activity
// are proven end-to-end. A broken top-level navigation item must not ship.
export const COMMUNITY_LAUNCH_ENABLED = process.env.NEXT_PUBLIC_COMMUNITY_LAUNCH_ENABLED === 'true';
