import { ipcRenderer, contextBridge } from 'electron';
import type { Document, NewDocument, AddProgressLogPayload, Todo, Paper, ConceptData } from '../src/types';

const api = {
  getDocuments: (): Promise<Document[]> => ipcRenderer.invoke('get-documents'),
  addDocument: (doc: NewDocument): Promise<Document[]> => ipcRenderer.invoke('add-document', doc),
  addProgressLog: (payload: AddProgressLogPayload): Promise<Document[]> => ipcRenderer.invoke('add-progress-log', payload),
  deleteDocument: (docId: number): Promise<Document[]> => ipcRenderer.invoke('delete-document', docId),
  saveDocuments: (documents: Document[]): Promise<Document[]> => ipcRenderer.invoke('save-documents', documents),
  
  // Add these two lines:
  updateDocument: (doc: Document): Promise<Document[]> => ipcRenderer.invoke('update-document', doc),
  openLink: (link: string): Promise<void> => ipcRenderer.invoke('open-link', link),
  
  getTodos: (): Promise<Todo[]> => ipcRenderer.invoke('get-todos'),
  saveTodos: (todos: Todo[]): Promise<Todo[]> => ipcRenderer.invoke('save-todos', todos),
  
  getPapers: (): Promise<Paper[]> => ipcRenderer.invoke('get-papers'),
  savePapers: (papers: Paper[]): Promise<Paper[]> => ipcRenderer.invoke('save-papers', papers),
  
  getMemo: (): Promise<string> => ipcRenderer.invoke('get-memo'),
  saveMemo: (memo: string): Promise<string> => ipcRenderer.invoke('save-memo', memo),
  
  exportData: (): Promise<boolean> => ipcRenderer.invoke('export-data'),
  importData: (): Promise<boolean> => ipcRenderer.invoke('import-data'),

  getConcepts: (): Promise<ConceptData> => ipcRenderer.invoke('get-concepts'),
  saveConcepts: (concepts: ConceptData): Promise<ConceptData> => ipcRenderer.invoke('save-concepts', concepts),
};

contextBridge.exposeInMainWorld('api', api);
