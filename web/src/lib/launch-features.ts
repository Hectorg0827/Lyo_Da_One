// Launch containment: false until production community data, map and activity
// are proven end-to-end. A broken top-level navigation item must not ship.
export const COMMUNITY_LAUNCH_ENABLED = process.env.NEXT_PUBLIC_COMMUNITY_LAUNCH_ENABLED === 'true';

// Until clips survive redeploy and both legacy media play end-to-end.
export const DISCOVER_LAUNCH_ENABLED = process.env.NEXT_PUBLIC_DISCOVER_LAUNCH_ENABLED === 'true';

// Navigation-only preview affordance. Keeps Discover's playback gate off while
// showing its tab, which leads to the existing explicit unavailable screen.
// Never enable this variable on production services.
export const PREVIEW_SHOW_GATED_DISCOVER_TAB = process.env.NEXT_PUBLIC_PREVIEW_SHOW_GATED_DISCOVER_TAB === 'true';
