import { useState, useEffect } from 'react';
import { FaBookReader, FaPlus, FaTrash, FaList, FaThLarge } from 'react-icons/fa';
import './App.css';
import type { Document, NewDocument, AddProgressLogPayload } from './types';
import { AddDocumentModal } from './AddDocumentModal';
import { ErrorDisplay } from './ErrorDisplay';
import { OverviewPage } from './OverviewPage';
import { PlanningPage } from './PlanningPage';
import { PapersPage } from './PapersPage';
import KnowledgeGraphPage from './KnowledgeGraphPage';
import { FaFileAlt, FaCheckSquare } from 'react-icons/fa';

type View = 'details' | 'overview' | 'papers' | 'planning' | 'graph';

function App() {
  const [documents, setDocuments] = useState<Document[]>([]);

  const handleUpdateDocumentField = (field: keyof Document, value: string | number | undefined) => {
    if (!selectedDocument) return;
    const updatedDoc = { ...selectedDocument, [field]: value };
    
    window.api.updateDocument(updatedDoc)
      .then(updatedDocs => {
        setDocuments(updatedDocs);
        setSelectedDocument(updatedDoc);
      })
      .catch((err: Error) => setError(err.message));
  };
  const [selectedDocument, setSelectedDocument] = useState<Document | null>(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [view, setView] = useState<View>('details');
  const [error, setError] = useState<string | null>(null);

  // State for the next progress log
  const [nextPage, setNextPage] = useState<number | string>('');
  const [nextTopic, setNextTopic] = useState('');
  const [nextSatisfaction, setNextSatisfaction] = useState<number | string>('');

  const getLatestLog = (doc: Document | null) => {
    if (!doc || doc.progressLogs.length === 0) return null;
    return doc.progressLogs[doc.progressLogs.length - 1];
  };

  useEffect(() => {
    window.api.getDocuments()
      .then((docs) => {
        setDocuments(docs);
        if (docs.length > 0) {
          setSelectedDocument(docs[0]);
        } else {
          setSelectedDocument(null);
        }
      })
      .catch((err: Error) => setError(err.message));
  }, []);

  useEffect(() => {
    const latestLog = getLatestLog(selectedDocument);
    setNextPage(latestLog?.page ?? '');
    setNextTopic('');
    setNextSatisfaction('');
  }, [selectedDocument?.id, selectedDocument]);

  const handleAddDocument = async (newDoc: NewDocument) => {
    window.api.addDocument(newDoc)
      .then(updatedDocs => {
        setDocuments(updatedDocs);
        setShowAddModal(false);
        setSelectedDocument(updatedDocs[updatedDocs.length - 1]);
      })
      .catch((err: Error) => setError(err.message));
  };

  const handleAddProgressLog = async () => {
    if (!selectedDocument || nextPage === '') return;
    const page = Number(nextPage);
    if (!Number.isInteger(page) || page < 0) {
      setError('Please enter a valid page number.');
      return;
    }

    const latestLog = getLatestLog(selectedDocument);
    if(latestLog && page < latestLog.page) {
      if(!window.confirm('The page number is less than the previous log. Are you sure you want to proceed?')) {
        return;
      }
    }

    const payload: AddProgressLogPayload = {
      docId: selectedDocument.id,
      page: Math.min(page, selectedDocument.totalPages),
      topic: nextTopic,
      satisfaction: nextSatisfaction ? parseInt(String(nextSatisfaction), 10) : undefined,
    };
    
    window.api.addProgressLog(payload)
      .then(updatedDocs => {
        setDocuments(updatedDocs);
        const updatedSelectedDoc = updatedDocs.find(doc => doc.id === selectedDocument.id);
        if (updatedSelectedDoc) {
          setSelectedDocument(updatedSelectedDoc);
          const newLatestLog = getLatestLog(updatedSelectedDoc);
          setNextPage(newLatestLog?.page ?? '');
          setNextTopic('');
          setNextSatisfaction('');
        }
      })
      .catch((err: Error) => setError(err.message));
  };

  const handleDeleteDocument = async () => {
    if (!selectedDocument) return;
    if (window.confirm('Are you sure you want to delete this document? All its logs will be lost.')) {
      const docId = selectedDocument.id;
      window.api.deleteDocument(docId)
        .then(updatedDocs => {
          setDocuments(updatedDocs);
          if (selectedDocument?.id === docId) {
            setSelectedDocument(updatedDocs.length > 0 ? updatedDocs[0] : null);
          }
        })
        .catch((err: Error) => setError(err.message));
    }
  };

  const handleOrderChange = (reorderedDocs: Document[]) => {
    window.api.saveDocuments(reorderedDocs)
      .then(savedDocs => {
        setDocuments(savedDocs);
      })
      .catch((err: Error) => setError(err.message));
  };
  
  const latestLog = getLatestLog(selectedDocument);
  const currentPage = latestLog?.page ?? 0;
  const remainingPages = selectedDocument ? selectedDocument.totalPages - currentPage : 0;
  const overallProgress = selectedDocument ? Math.round((currentPage / selectedDocument.totalPages) * 100) : 0;

  let mainContent;
  if (view === 'details') {
    mainContent = (
      <>
        <div className="col-4 border-end mh-100" style={{ overflowY: 'auto' }}>
        <div className="d-flex justify-content-between align-items-center mb-3 p-2 sticky-top">
          <h2>Documents</h2>
          <button className="btn btn-primary" onClick={() => setShowAddModal(true)}> <FaPlus /> </button>
        </div>
        <div className="list-group">
          {documents.map((doc) => {
            const lastLog = getLatestLog(doc);
            const progress = lastLog ? Math.round((lastLog.page / doc.totalPages) * 100) : 0;
            return (
              <div key={doc.id} className={`list-group-item ${selectedDocument?.id === doc.id ? 'active' : ''}`} onClick={() => setSelectedDocument(doc)}>
                <div className="card">
                  <div className="card-body">
                    <h5 className="card-title mb-1">{doc.title}</h5>
                    <p className="text-muted mb-2">{doc.totalPages} pages</p>
                    <div className="progress">
                      <div className="progress-bar" role="progressbar" style={{ width: `${progress}%` }}></div>
                    </div>
                    <small className="text-muted">{progress}% complete</small>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
      <div className="col-8 p-4 mh-100" style={{ overflowY: 'auto' }}>
        {/* 👇 여기서부터 추가 (너비를 제한하고 가운데 정렬) */}
        <div style={{ maxWidth: '850px', margin: '0 auto', width: '100%' }}>
          
          {selectedDocument ? (
            <div>
              <div className="d-flex justify-content-between align-items-start mb-3">
                <div>
                  <small className='text-muted'>Difficulty: {selectedDocument.difficulty ? `${selectedDocument.difficulty}/5` : 'N/A'}</small>
                  <h2 className="mb-1">{selectedDocument.title}</h2>
                </div>
                <div className='text-end' style={{ minWidth: '200px' }}>
                  <div className="mb-2">
                    <small className='text-muted d-block'>Target Date</small>
                    <input 
                      type="date" 
                      className="form-control form-control-sm bg-dark text-light border-secondary" 
                      value={selectedDocument.targetDate?.split('T')[0] || ''}
                      onChange={(e) => handleUpdateDocumentField('targetDate', e.target.value)}
                    />
                  </div>
                  <div>
                    <small className='text-muted d-block'>Shortcut Link / Path</small>
                    <div className="input-group input-group-sm">
                      <input 
                        type="text" 
                        className="form-control bg-dark text-light border-secondary" 
                        placeholder="C:/... or https://..."
                        value={selectedDocument.link || ''}
                        onChange={(e) => handleUpdateDocumentField('link', e.target.value)}
                      />
                      {selectedDocument.link && (
                        <button 
                          className="btn btn-outline-primary" 
                          onClick={() => window.api.openLink(selectedDocument.link!)}
                        >
                          Open
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              </div>
              <p className="text-muted">
                {selectedDocument.totalPages} pages total | <span className='fw-bold'>{remainingPages} pages remaining ({overallProgress}%)</span>
              </p>
              <hr className="hr" />
              <div className="card mb-4">
                <div className="card-body">
                  <h5 className="card-title">Log Progress</h5>
                  <div className="row align-items-end">
                    <div className="col">
                      <label htmlFor="nextPage" className="form-label">Page</label>
                      <input type="number" className="form-control" id="nextPage" value={nextPage} onChange={(e) => setNextPage(e.target.value)} />
                    </div>
                    <div className="col">
                      <label htmlFor="nextTopic" className="form-label">Topic</label>
                      <input type="text" className="form-control" id="nextTopic" value={nextTopic} onChange={(e) => setNextTopic(e.target.value)} />
                    </div>
                      <div className="col">
                      <label htmlFor="nextSatisfaction" className="form-label">Satisfaction (1-5)</label>
                      <input type="number" className="form-control" id="nextSatisfaction" value={nextSatisfaction} onChange={(e) => setNextSatisfaction(e.target.value)} min="1" max="5" />
                    </div>
                    <div className='col-auto'>
                        <button className="btn btn-success" onClick={handleAddProgressLog}>Log</button>
                    </div>
                  </div>
                </div>
              </div>
              <h3>Reading History</h3>
              {[...selectedDocument.progressLogs].reverse().map((log) => (
                <div key={log.id} className="card mb-2">
                  <div className="card-body">
                      <div className="d-flex justify-content-between align-items-center">
                      <h5 className="card-title mb-1">Page {log.page}</h5>
                      <small className='text-muted'>{new Date(log.date).toLocaleString()}</small>
                    </div>
                    <p className="mb-1 text-muted">{log.topic || 'No topic'}</p>
                    {log.satisfaction && <small>Satisfaction: {log.satisfaction}/5</small>}
                  </div>
                </div>
              ))}
                <div className='mt-4 d-flex justify-content-end'>
                  <button className="btn btn-outline-danger" onClick={handleDeleteDocument}><FaTrash className='me-2'/> Delete Document</button>
              </div>
            </div>
          ) : (
            <div className="text-center d-flex flex-column justify-content-center align-items-center h-100 text-muted">
              <FaBookReader size="5em" className="mb-3" />
              <h3>Select a document to see its details</h3>
              <p>or add a new one to get started.</p>
            </div>
          )}
          
        </div> {/* 👈 추가된 div 닫기 */}
      </div>
    </>
    );
  } else if (view === 'overview') {
    mainContent = <OverviewPage documents={documents} onOrderChange={handleOrderChange} />;
  } else if (view === 'papers') {
    mainContent = <PapersPage />;
  } else if (view === 'planning') {
    mainContent = <PlanningPage />;
  } else if (view === 'graph') {
    mainContent = <KnowledgeGraphPage />;
  }

  return (
    <>
      <div className="container-fluid vh-100 d-flex flex-column p-4">
        <header className="d-flex justify-content-between align-items-center mb-4 pb-3 border-bottom border-secondary">
          <div>
            <h1 className="h3 mb-0 text-white"><FaBookReader className="me-2"/>Reading Progress Tracker</h1>
          </div>
          <div className="btn-group">
            <button type="button" className={`btn btn-sm ${view === 'details' ? 'btn-primary' : 'btn-outline-primary'}`} onClick={() => setView('details')}>
              <FaList className='me-2'/> Details
            </button>
            <button type="button" className={`btn btn-sm ${view === 'overview' ? 'btn-primary' : 'btn-outline-primary'}`} onClick={() => setView('overview')}>
              <FaThLarge className='me-2'/> Overview
            </button>
            <button type="button" className={`btn btn-sm ${view === 'papers' ? 'btn-primary' : 'btn-outline-primary'}`} onClick={() => setView('papers')}>
              <FaFileAlt className='me-2'/> Papers
            </button>
            <button type="button" className={`btn btn-sm ${view === 'planning' ? 'btn-primary' : 'btn-outline-primary'}`} onClick={() => setView('planning')}>
              <FaCheckSquare className='me-2'/> To-Do & Memo
            </button>
            <button type="button" className={`btn btn-sm ${view === 'graph' ? 'btn-primary' : 'btn-outline-primary'}`} onClick={() => setView('graph')}>
              🧠 Knowledge Graph
            </button>
          </div>
          <div className="btn-group ms-3">
            <button 
              className="btn btn-sm btn-outline-info" 
              onClick={async () => {
                const success = await window.api.exportData();
                if (success) alert('Data exported successfully!');
              }}
            >
              Export
            </button>
            <button 
              className="btn btn-sm btn-outline-warning" 
              onClick={async () => {
                const success = await window.api.importData();
                if (success) {
                  alert('Data imported successfully! The app will now reload.');
                  window.location.reload();
                }
              }}
            >
              Import
            </button>
          </div>
        </header>
        <main className="row flex-grow-1" style={{ overflow: 'hidden' }}>
          {mainContent}
        </main>
      </div>
      <AddDocumentModal 
        show={showAddModal}
        onClose={() => setShowAddModal(false)}
        onAdd={handleAddDocument}
      />
      {error && <ErrorDisplay message={error} onDismiss={() => setError(null)} />}
    </>
  );
}
export default App;
