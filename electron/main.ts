import { app, BrowserWindow, ipcMain, shell, dialog } from 'electron'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import fs from 'node:fs/promises'
import type { Document, ProgressLog } from '../src/types';

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// The built directory structure
//
// ├─┬─┬ dist
// │ │ └── index.html
// │ │
// │ ├─┬ dist-electron
// │ │ ├── main.js
// │ │ └── preload.mjs
// │
process.env.APP_ROOT = path.join(__dirname, '..')

// 🚧 Use ['ENV_NAME'] avoid vite:define plugin - Vite@2.x
export const VITE_DEV_SERVER_URL = process.env['VITE_DEV_SERVER_URL']
export const MAIN_DIST = path.join(process.env.APP_ROOT, 'dist-electron')
export const RENDERER_DIST = path.join(process.env.APP_ROOT, 'dist')

process.env.VITE_PUBLIC = VITE_DEV_SERVER_URL ? path.join(process.env.APP_ROOT, 'public') : RENDERER_DIST

let win: BrowserWindow | null

function createWindow() {
  win = new BrowserWindow({
    width: 1440,
    height: 900,
    icon: path.join(process.env.VITE_PUBLIC || '', 'electron-vite.svg'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.mjs'),
    },
  })

  // Test active push message to Renderer-process.
  win.webContents.on('did-finish-load', () => {
    win?.webContents.send('main-process-message', (new Date).toLocaleString())
  })

  if (VITE_DEV_SERVER_URL) {
    win.loadURL(VITE_DEV_SERVER_URL)
  } else {
    // win.loadFile('dist/index.html')
    win.loadFile(path.join(RENDERER_DIST, 'index.html'))
  }
}

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
    win = null
  }
})

app.on('activate', () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow()
  }
})

app.whenReady().then(() => {
  const userDataPath = app.getPath('userData');
  const dataPath = path.join(userDataPath, 'data.json');
  const papersPath = path.join(userDataPath, 'papers.json');
  const todosPath = path.join(userDataPath, 'todos.json');
  const memoPath = path.join(userDataPath, 'memo.json');

  ipcMain.handle('get-documents', async () => {
    try {
      await fs.access(dataPath).catch(async () => {
        await fs.mkdir(path.dirname(dataPath), { recursive: true });
        await fs.writeFile(dataPath, JSON.stringify([], null, 2));
      });
      const data = await fs.readFile(dataPath, 'utf-8');
      return JSON.parse(data);
    } catch (error) {
      console.error('Failed to get documents:', error);
      throw new Error('Failed to load documents.');
    }
  });

  ipcMain.handle('add-document', async (_event, newDoc: { title: string, totalPages: number, targetDate: string, difficulty?: number }) => {
    try {
      const data = await fs.readFile(dataPath, 'utf-8');
      const documents: Document[] = JSON.parse(data);
      const newId = documents.length > 0 ? Math.max(...documents.map(d => d.id)) + 1 : 1;
      const finalDoc: Document = { 
        id: newId, 
        title: newDoc.title,
        totalPages: newDoc.totalPages,
        targetDate: newDoc.targetDate,
        difficulty: newDoc.difficulty,
        progressLogs: [] 
      };
      documents.push(finalDoc);
      await fs.writeFile(dataPath, JSON.stringify(documents, null, 2));
      return documents;
    } catch (error) {
      console.error('Failed to add document:', error);
      throw new Error('Failed to save the new document.');
    }
  });

  ipcMain.handle('add-progress-log', async (_event, { docId, page, topic, satisfaction }) => {
    try {
      const data = await fs.readFile(dataPath, 'utf-8');
      const documents: Document[] = JSON.parse(data);
      const docIndex = documents.findIndex(d => d.id === docId);
      if (docIndex === -1) throw new Error('Document not found.');

      const doc = documents[docIndex];
      const newLogId = doc.progressLogs.length > 0 ? Math.max(...doc.progressLogs.map(l => l.id)) + 1 : 1;
      
      const newLog: ProgressLog = { id: newLogId, date: new Date().toISOString(), page, topic, satisfaction };
      doc.progressLogs.push(newLog);
      
      documents[docIndex] = doc;
      await fs.writeFile(dataPath, JSON.stringify(documents, null, 2));
      return documents;
    } catch (error) {
      console.error('Failed to add progress log:', error);
      throw new Error('Failed to save the progress log.');
    }
  });

  ipcMain.handle('delete-document', async (_event, docId) => {
    try {
      const data = await fs.readFile(dataPath, 'utf-8');
      let documents: Document[] = JSON.parse(data);
      documents = documents.filter(d => d.id !== docId);
      await fs.writeFile(dataPath, JSON.stringify(documents, null, 2));
      return documents;
    } catch (error) {
      console.error('Failed to delete document:', error);
      throw new Error('Failed to delete the document.');
    }
  });

  ipcMain.handle('save-documents', async (_event, documents: Document[]) => {
    try {
      await fs.writeFile(dataPath, JSON.stringify(documents, null, 2));
      return documents;
    } catch (error) {
      console.error('Failed to save documents:', error);
      throw new Error('Failed to save the new document order.');
    }
  });

  ipcMain.handle('update-document', async (_event, updatedDoc: Document) => {
    try {
      const data = await fs.readFile(dataPath, 'utf-8');
      const documents: Document[] = JSON.parse(data);
      const docIndex = documents.findIndex(d => d.id === updatedDoc.id);
      
      if (docIndex !== -1) {
        documents[docIndex] = updatedDoc;
        await fs.writeFile(dataPath, JSON.stringify(documents, null, 2));
      }
      return documents;
    } catch (error) {
      console.error('Failed to update document:', error);
      throw new Error('Failed to update the document.');
    }
  });

  ipcMain.handle('open-link', async (_event, link: string) => {
    try {
      // shell.openPath handles local files (C:/...), openExternal handles URLs (http://...)
      if (link.startsWith('http://') || link.startsWith('https://')) {
        await shell.openExternal(link);
      } else {
        await shell.openPath(link);
      }
    } catch (error) {
      console.error('Failed to open link:', error);
    }
  });

  ipcMain.handle('get-papers', async () => {
    try {
      await fs.access(papersPath).catch(async () => {
        await fs.writeFile(papersPath, JSON.stringify([], null, 2));
      });
      const data = await fs.readFile(papersPath, 'utf-8');
      return JSON.parse(data);
    } catch (error) {
      console.error('Failed to get papers:', error);
      return [];
    }
  });

  ipcMain.handle('save-papers', async (_event, papers) => {
    try {
      await fs.writeFile(papersPath, JSON.stringify(papers, null, 2));
      return papers;
    } catch (error) {
      console.error('Failed to save papers:', error);
      throw new Error('Failed to save papers.');
    }
  });

  ipcMain.handle('get-todos', async () => {
    try {
      await fs.access(todosPath).catch(async () => {
        await fs.writeFile(todosPath, JSON.stringify([], null, 2));
      });
      const data = await fs.readFile(todosPath, 'utf-8');
      return JSON.parse(data);
    } catch (error) {
      console.error('Failed to get todos:', error);
      return [];
    }
  });

  ipcMain.handle('save-todos', async (_event, todos) => {
    try {
      await fs.writeFile(todosPath, JSON.stringify(todos, null, 2));
      return todos;
    } catch (error) {
      console.error('Failed to save todos:', error);
      throw new Error('Failed to save todos.');
    }
  });

  ipcMain.handle('get-memo', async () => {
    try {
      await fs.access(memoPath).catch(async () => {
        await fs.writeFile(memoPath, JSON.stringify("", null, 2));
      });
      const data = await fs.readFile(memoPath, 'utf-8');
      return JSON.parse(data);
    } catch (error) {
      console.error('Failed to get memo:', error);
      return "";
    }
  });

  ipcMain.handle('save-memo', async (_event, memo) => {
    try {
      await fs.writeFile(memoPath, JSON.stringify(memo, null, 2));
      return memo;
    } catch (error) {
      console.error('Failed to save memo:', error);
      throw new Error('Failed to save memo.');
    }
  });

  ipcMain.handle('export-data', async () => {
    try {
      const { canceled, filePath } = await dialog.showSaveDialog({
        title: 'Export Sync Data',
        defaultPath: 'reading-tracker-sync.json',
        filters: [{ name: 'JSON', extensions: ['json'] }]
      });

      if (canceled || !filePath) return false;

      const dataStr = await fs.readFile(dataPath, 'utf-8').catch(() => '[]');
      const papersStr = await fs.readFile(papersPath, 'utf-8').catch(() => '[]');
      const todosStr = await fs.readFile(todosPath, 'utf-8').catch(() => '[]');
      const memoStr = await fs.readFile(memoPath, 'utf-8').catch(() => '""');

      const exportObj = {
        data: JSON.parse(dataStr),
        papers: JSON.parse(papersStr),
        todos: JSON.parse(todosStr),
        memo: JSON.parse(memoStr)
      };

      await fs.writeFile(filePath, JSON.stringify(exportObj, null, 2), 'utf-8');
      return true;
    } catch (error) {
      console.error('Export failed:', error);
      throw error;
    }
  });

  ipcMain.handle('import-data', async () => {
    try {
      const { canceled, filePaths } = await dialog.showOpenDialog({
        title: 'Import Sync Data',
        filters: [{ name: 'JSON', extensions: ['json'] }],
        properties: ['openFile']
      });

      if (canceled || filePaths.length === 0) return false;

      const importContent = await fs.readFile(filePaths[0], 'utf-8');
      const importObj = JSON.parse(importContent);

      if (importObj.data) await fs.writeFile(dataPath, JSON.stringify(importObj.data, null, 2));
      if (importObj.papers) await fs.writeFile(papersPath, JSON.stringify(importObj.papers, null, 2));
      if (importObj.todos) await fs.writeFile(todosPath, JSON.stringify(importObj.todos, null, 2));
      if (importObj.memo !== undefined) await fs.writeFile(memoPath, JSON.stringify(importObj.memo, null, 2));

      return true;
    } catch (error) {
      console.error('Import failed:', error);
      throw error;
    }
  });

  createWindow();
})
