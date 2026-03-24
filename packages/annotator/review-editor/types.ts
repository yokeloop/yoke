// Forked from plannotator/packages/review-editor
export interface DiffFile {
  path: string;
  oldPath?: string;
  patch: string;
  additions: number;
  deletions: number;
}
