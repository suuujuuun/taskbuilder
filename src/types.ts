export interface ProgressLog {
  id: number;
  date: string; // ISO date string
  page: number;
  topic: string;
  satisfaction?: number; // e.g., 1-5 rating
}

export interface Document {
  id: number;
  title: string;
  totalPages: number;
  targetDate: string; // ISO date string
  difficulty?: number; // e.g., 1-5 rating
  link?: string; // <-- Add this line
  progressLogs: ProgressLog[];
}

export type NewDocument = Omit<Document, 'id' | 'progressLogs'>;

// This will become the payload for adding a new log
export interface AddProgressLogPayload {
  docId: number;
  page: number;
  topic: string;
  satisfaction?: number;
}

export interface Todo {
  id: number;
  text: string;
  completed: boolean;
}

export type PaperStatus = 'Not Started' | 'In Progress' | 'Completed';

export interface Paper {
  id: number;
  title: string;
  url: string;
  status: PaperStatus;
}
