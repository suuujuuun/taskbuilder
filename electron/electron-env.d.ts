/// <reference types="vite-plugin-electron/electron-env" />

declare namespace NodeJS {
  interface ProcessEnv {
    /**
     * The built directory structure
     *
     * ```tree
     * ├─┬─┬ dist
     * │ │ └── index.html
     * │ │
     * │ ├─┬ dist-electron
     * │ │ ├── main.js
     * │ │ └── preload.js
     * │
     * ```
     */
    APP_ROOT: string
    /** /dist/ or /public/ */
    VITE_PUBLIC: string
  }
}

import type { Document, NewDocument, AddProgressLogPayload } from '../src/types';

// Used in Renderer process, expose in `preload.ts`
interface Window {
  api: {
    getDocuments: () => Promise<Document[]>;
    addDocument: (doc: NewDocument) => Promise<Document[]>;
    addProgressLog: (payload: AddProgressLogPayload) => Promise<Document[]>;
    deleteDocument: (docId: number) => Promise<Document[]>;
    saveDocuments: (documents: Document[]) => Promise<Document[]>;
  }
}
