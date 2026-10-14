/** A place you can navigate to. */
export interface NavRoute {
  key: string;
  label: string;
  href: string;
  action?: undefined;
}

/** Not a place: `create` opens the shared creation sheet where you stand. */
export interface NavAction {
  key: string;
  label: string;
  action: 'create';
  href?: undefined;
}

export type NavItem = NavRoute | NavAction;

export const NAV: {
  focus: NavRoute;
  askLyo: NavRoute;
  courses: NavRoute;
  testPrep: NavRoute;
  community: NavRoute;
  discover: NavRoute;
  create: NavAction;
  profile: NavRoute;
};

export const SIDEBAR_ITEMS: NavItem[];

/** The labels iOS, Android and the web must all agree on. */
export const CROSS_PLATFORM_LABELS: Record<'focus' | 'discover' | 'community' | 'create', string>;

export function isActiveHref(href: string | undefined, pathname: string): boolean;

export const RAIL_STORAGE_KEY: string;
export function readCollapsed(storage: Storage | null | undefined): boolean;
export function writeCollapsed(storage: Storage | null | undefined, collapsed: boolean): boolean;
export function isRailShortcut(event: KeyboardEvent | null | undefined): boolean;
