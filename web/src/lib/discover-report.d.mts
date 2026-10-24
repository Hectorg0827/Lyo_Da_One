export interface ReportReason { value: string; label: string; }
export const REPORT_REASONS: ReportReason[];
export const REPORT_NOTE_LIMIT: number;
export function canReport(ownerId: string | number | null | undefined, viewerId: string | number | null | undefined): boolean;
export interface ReportOutcome { leaveFeed: boolean; message: string; }
export function reportOutcome(status: number): ReportOutcome;
export function pagesToFetch(page: number, reports: number, perPage: number): number[];
