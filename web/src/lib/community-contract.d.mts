import type { LearningNode, LearningNodeCategory } from '@/types';

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface SearchArea extends GeoPoint {
  radiusKm: number;
}

export interface MapBounds {
  north: number;
  south: number;
  east: number;
  west: number;
}

export type FilterId =
  | 'events'
  | 'libraries'
  | 'museums'
  | 'classes'
  | 'workshops'
  | 'study_groups'
  | 'schools'
  | 'learning_centers'
  | 'tutors'
  | 'free'
  | 'today'
  | 'week'
  | 'nearby';

export interface FilterDefinition {
  id: FilterId;
  label: string;
  categories?: LearningNodeCategory[];
  placeTypes?: string[];
  modifier?: 'free' | 'when' | 'nearby';
  value?: 'today' | 'week';
}

export interface FilterQuery {
  categories: LearningNodeCategory[];
  placeTypes: string[];
  freeOnly: boolean;
  when: 'today' | 'week' | null;
  nearby: boolean;
}

export interface NodeCluster {
  id: string;
  latitude: number;
  longitude: number;
  members: LearningNode[];
  bounds: MapBounds;
}

export interface FriendlyError {
  title: string;
  body: string;
  retry: boolean;
}

export const DEFAULT_CENTER: Readonly<GeoPoint & { label: string }>;
export const DEFAULT_RADIUS_KM: number;
export const NEARBY_RADIUS_KM: number;
export const MAX_SEARCH_RADIUS_KM: number;
export const NODE_CATEGORIES: LearningNodeCategory[];
export const SCHOOL_PLACE_TYPES: string[];
export const LEARNING_CENTER_PLACE_TYPES: string[];
export const FILTERS: FilterDefinition[];
export const CATEGORY_LABELS: Record<LearningNodeCategory, string>;
export const LIFECYCLE_LABELS: Record<string, string>;

export function toggleFilter(active: Set<FilterId>, id: FilterId): Set<FilterId>;
export function filtersToQuery(active: Set<FilterId>): FilterQuery;
export function activeFilterLabels(active: Set<FilterId>): string[];
export function distanceKm(a: GeoPoint, b: GeoPoint): number;
export function areaForBounds(bounds: MapBounds): SearchArea;
export function shouldOfferAreaSearch(searched: SearchArea | null, visible: SearchArea | null): boolean;
export function clusterNodes(
  nodes: LearningNode[],
  project: (node: LearningNode) => { x: number; y: number },
  cellPx?: number,
): NodeCluster[];
export function categoryLabel(node: Pick<LearningNode, 'category' | 'place_type'>): string;
export function formatDistance(km: number | null | undefined): string | null;
export function formatPrice(node: Pick<LearningNode, 'is_free' | 'price_amount' | 'currency'>): string | null;
export function formatWhen(
  startsAt?: string | null,
  endsAt?: string | null,
  locale?: string,
  timeZone?: string,
): string | null;
export function safeWebUrl(value?: string | null): string | null;
export function directionsUrl(node: LearningNode): string | null;
export function detailPath(node: Pick<LearningNode, 'kind' | 'id'>): string;
export function buildIcs(node: LearningNode, pageUrl?: string): string | null;
export function googleCalendarUrl(node: LearningNode): string | null;
export function friendlyError(error: unknown, action?: string): FriendlyError;

export function inviteTokenFromText(text: string | null | undefined): string | null;
export function invitePath(token: string): string;
export const INVITE_STATUS_COPY: Record<'expired' | 'revoked' | 'used_up' | 'ended' | 'cancelled', { title: string; body: string }>;
export function describeInviteLink(
  link: { active: boolean; use_count: number; max_uses?: number | null; expires_at?: string | null },
  now?: Date,
  locale?: string,
  timeZone?: string,
): string;
