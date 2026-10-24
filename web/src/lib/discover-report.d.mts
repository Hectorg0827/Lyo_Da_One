export interface ReportReason { value: string; label: string; }
export const REPORT_REASONS: ReportReason[];
export const REPORT_NOTE_LIMIT: number;
export function canReport(ownerId: string | number | null | undefined, viewerId: string | number | null | undefined): boolean;
export function canBlock(ownerId: string | number | null | undefined, viewerId: string | number | null | undefined, isLibrary: boolean): boolean;
export interface BlockOutcome { blocked: boolean; message: string; }
export function blockOutcome(status: number, name: string): BlockOutcome;
export interface ReportOutcome { leaveFeed: boolean; message: string; }
export function reportOutcome(status: number): ReportOutcome;
export function pagesToFetch(page: number, removed: number, perPage: number): number[];
