/// <reference types="vite/client" />
/// <reference types="../electron/electron-env" />

import type { Document, NewDocument, AddProgressLogPayload, Todo, Paper } from './types';

declare global {
  interface Window {
    api: {
      getDocuments: () => Promise<Document[]>;
      addDocument: (newDoc: NewDocument) => Promise<Document[]>;
      addProgressLog: (payload: AddProgressLogPayload) => Promise<Document[]>;
      deleteDocument: (id: number) => Promise<Document[]>;
      saveDocuments: (docs: Document[]) => Promise<Document[]>;
      updateDocument: (doc: Document) => Promise<Document[]>;
      openLink: (link: string) => Promise<void>;
      
      // New methods
      getTodos: () => Promise<Todo[]>;
      saveTodos: (todos: Todo[]) => Promise<Todo[]>;
      
      getPapers: () => Promise<Paper[]>;
      savePapers: (papers: Paper[]) => Promise<Paper[]>;
      
      getMemo: () => Promise<string>;
      saveMemo: (memo: string) => Promise<string>;
      
      exportData: () => Promise<boolean>;
      importData: () => Promise<boolean>;

      getConcepts: () => Promise<import('./types').ConceptData>;
      saveConcepts: (concepts: import('./types').ConceptData) => Promise<import('./types').ConceptData>;
    };
  }
}
