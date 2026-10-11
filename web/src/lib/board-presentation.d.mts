export type PresentationRole = 'narration' | 'board' | 'reference' | 'practice' | 'feedback' | 'recovery' | 'details';
export type BoardBlock =
  | { kind: 'text'; text: string }
  | { kind: 'code'; text: string; language?: string }
  | { kind: 'steps' | 'bullets'; items: string[] }
  | { kind: 'table'; headers: string[]; rows: string[][] };
export interface BoardDocument { version: 1; blocks: BoardBlock[] }
export function parseBoardDocument(value: unknown): BoardDocument | null;
export function presentationRoleFor(component: { type?: string; component_id?: string; presentation_role?: unknown; block_type?: string }): PresentationRole;
export function workspaceGroups<T extends { kind: string; presentationRole?: PresentationRole }>(elements: T[]): Record<'board' | 'reference' | 'practice' | 'feedback' | 'recovery' | 'details', T[]>;
export function classroomIsPaused(elements: { id: string; presentationRole?: PresentationRole }[]): boolean;
export function workspaceScrollAnchor(elements: { id: string; kind: string; presentationRole?: PresentationRole }[]): string | undefined;
