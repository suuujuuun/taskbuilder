import { useState, useEffect } from 'react';
import type { Paper, PaperStatus } from './types';
import { DndProvider, useDrag, useDrop } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { FaTrash, FaExternalLinkAlt, FaPlus } from 'react-icons/fa';

const ItemTypes = {
  PAPER: 'paper',
};

// ------------------- Card Component -------------------
interface PaperCardProps {
  paper: Paper;
  onDelete: (id: number) => void;
  onOpen: (link: string) => void;
}

const PaperCard = ({ paper, onDelete, onOpen }: PaperCardProps) => {
  const [{ isDragging }, dragRef] = useDrag(() => ({
    type: ItemTypes.PAPER,
    item: { id: paper.id },
    collect: (monitor) => ({
      isDragging: !!monitor.isDragging(),
    }),
  }));

  return (
    <div
      ref={dragRef}
      className={`card mb-3 shadow-sm border-secondary bg-dark text-light ${isDragging ? 'opacity-50' : ''}`}
      style={{ cursor: 'grab' }}
    >
      <div className="card-body p-3">
        <div className="d-flex justify-content-between align-items-start mb-2">
          <h6 className="card-title mb-0">{paper.title}</h6>
          <button 
            className="btn btn-sm text-danger p-0 ms-2" 
            onClick={() => onDelete(paper.id)}
            title="Delete Paper"
          >
            <FaTrash />
          </button>
        </div>
        <div className="text-end">
          <button 
            className="btn btn-sm btn-outline-primary py-0 px-2 mt-2" 
            onClick={() => onOpen(paper.url)}
            disabled={!paper.url}
          >
            <FaExternalLinkAlt className="me-1" size="0.8em" /> Open
          </button>
        </div>
      </div>
    </div>
  );
};

// ------------------- Column Component -------------------
interface ColumnProps {
  status: PaperStatus;
  papers: Paper[];
  onDropPaper: (id: number, status: PaperStatus) => void;
  onDelete: (id: number) => void;
  onOpen: (link: string) => void;
}

const KanbanColumn = ({ status, papers, onDropPaper, onDelete, onOpen }: ColumnProps) => {
  const [{ isOver }, dropRef] = useDrop(() => ({
    accept: ItemTypes.PAPER,
    drop: (item: { id: number }) => onDropPaper(item.id, status),
    collect: (monitor) => ({
      isOver: !!monitor.isOver(),
    }),
  }));

  const bgColors: Record<PaperStatus, string> = {
    'Not Started': '#2f2f38',
    'In Progress': '#2d3748',
    'Completed': '#273f32'
  };

  return (
    <div className="col h-100 d-flex flex-column">
      <div 
        className={`card h-100 border-0 ${isOver ? 'border border-primary' : ''}`}
        style={{ backgroundColor: bgColors[status], transition: 'background-color 0.2s' }}
      >
        <div className="card-header border-0 bg-transparent py-3">
          <h5 className="mb-0 text-center">{status} <span className="badge bg-secondary ms-2">{papers.length}</span></h5>
        </div>
        <div 
          ref={dropRef} 
          className="card-body" 
          style={{ overflowY: 'auto', minHeight: '200px' }}
        >
          {papers.map((paper) => (
            <PaperCard 
              key={paper.id} 
              paper={paper} 
              onDelete={onDelete} 
              onOpen={onOpen} 
            />
          ))}
          {papers.length === 0 && (
            <div className="text-center text-muted small mt-4">Drop papers here</div>
          )}
        </div>
      </div>
    </div>
  );
};

// ------------------- Main Page Component -------------------
export function PapersPage() {
  const [papers, setPapers] = useState<Paper[]>([]);
  const [showAddModal, setShowAddModal] = useState(false);
  
  const [newTitle, setNewTitle] = useState('');
  const [newUrl, setNewUrl] = useState('');

  useEffect(() => {
    window.api.getPapers().then(setPapers);
  }, []);

  const handleDropPaper = (id: number, targetStatus: PaperStatus) => {
    setPapers(prev => {
      const updated = prev.map(p => p.id === id ? { ...p, status: targetStatus } : p);
      window.api.savePapers(updated);
      return updated;
    });
  };

  const handleDeletePaper = (id: number) => {
    if (window.confirm('Are you sure you want to delete this paper?')) {
      setPapers(prev => {
        const updated = prev.filter(p => p.id !== id);
        window.api.savePapers(updated);
        return updated;
      });
    }
  };

  const handleOpenLink = (url: string) => {
    if (url) window.api.openLink(url);
  };

  const handleAddPaper = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;

    const newPaper: Paper = {
      id: Date.now(),
      title: newTitle.trim(),
      url: newUrl.trim(),
      status: 'Not Started'
    };

    setPapers(prev => {
      const updated = [...prev, newPaper];
      window.api.savePapers(updated);
      return updated;
    });

    setNewTitle('');
    setNewUrl('');
    setShowAddModal(false);
  };

  const columns: PaperStatus[] = ['Not Started', 'In Progress', 'Completed'];

  return (
    <DndProvider backend={HTML5Backend}>
      <div className="h-100 p-4 d-flex flex-column">
        <div className="d-flex justify-content-between align-items-center mb-4">
          <h2 className="mb-0">Research Papers</h2>
          <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
            <FaPlus className="me-2" /> Add Paper
          </button>
        </div>

        <div className="row flex-grow-1 g-4" style={{ overflow: 'hidden' }}>
          {columns.map(status => (
            <KanbanColumn 
              key={status}
              status={status}
              papers={papers.filter(p => p.status === status)}
              onDropPaper={handleDropPaper}
              onDelete={handleDeletePaper}
              onOpen={handleOpenLink}
            />
          ))}
        </div>
      </div>

      {/* Add Paper Modal */}
      {showAddModal && (
        <div className="modal show d-block" style={{ backgroundColor: 'rgba(0,0,0,0.7)' }}>
          <div className="modal-dialog modal-dialog-centered">
            <div className="modal-content bg-dark text-light border-secondary">
              <form onSubmit={handleAddPaper}>
                <div className="modal-header border-secondary">
                  <h5 className="modal-title">Add New Paper</h5>
                  <button type="button" className="btn-close btn-close-white" onClick={() => setShowAddModal(false)}></button>
                </div>
                <div className="modal-body">
                  <div className="mb-3">
                    <label className="form-label">Title</label>
                    <input 
                      type="text" 
                      className="form-control bg-dark text-light border-secondary" 
                      value={newTitle} 
                      onChange={e => setNewTitle(e.target.value)}
                      required 
                    />
                  </div>
                  <div className="mb-3">
                    <label className="form-label">URL or Local Path</label>
                    <input 
                      type="text" 
                      className="form-control bg-dark text-light border-secondary" 
                      value={newUrl} 
                      onChange={e => setNewUrl(e.target.value)}
                      placeholder="https://... or C:/..."
                    />
                  </div>
                </div>
                <div className="modal-footer border-secondary">
                  <button type="button" className="btn btn-secondary" onClick={() => setShowAddModal(false)}>Cancel</button>
                  <button type="submit" className="btn btn-primary">Add Paper</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </DndProvider>
  );
}
