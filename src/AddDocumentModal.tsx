import { useState } from 'react';

interface AddDocumentModalProps {
  show: boolean;
  onClose: () => void;
  onAdd: (newDoc: { title: string; totalPages: number; targetDate: string; difficulty?: number }) => void;
}

export function AddDocumentModal({ show, onClose, onAdd }: AddDocumentModalProps) {
  const [title, setTitle] = useState('');
  const [totalPages, setTotalPages] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [difficulty, setDifficulty] = useState<number | string>('');

  const handleAdd = () => {
    if (!title || !totalPages || parseInt(totalPages, 10) <= 0 || !targetDate) {
      alert('Please fill out all fields with valid data.');
      return;
    }
    onAdd({ 
      title, 
      totalPages: parseInt(totalPages, 10), 
      targetDate,
      difficulty: difficulty ? parseInt(String(difficulty), 10) : undefined
    });
    // Reset fields
    setTitle('');
    setTotalPages('');
    setTargetDate('');
    setDifficulty('');
  };

  if (!show) {
    return null;
  }

  return (
    <div className="modal fade show" style={{ display: 'block' }} tabIndex={-1}>
      <div className="modal-dialog modal-dialog-centered">
        <div className="modal-content">
          <div className="modal-header">
            <h5 className="modal-title">Add New Document</h5>
            <button type="button" className="btn-close" onClick={onClose}></button>
          </div>
          <div className="modal-body">
            <form onSubmit={(e) => { e.preventDefault(); handleAdd(); }}>
              <div className="mb-3">
                <label htmlFor="title" className="form-label">Title</label>
                <input
                  type="text"
                  className="form-control"
                  id="title"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  required
                />
              </div>
              <div className='row'>
                <div className="col">
                  <label htmlFor="totalPages" className="form-label">Total Pages</label>
                  <input
                    type="number"
                    className="form-control"
                    id="totalPages"
                    value={totalPages}
                    onChange={(e) => setTotalPages(e.target.value)}
                    required
                  />
                </div>
                <div className="col">
                  <label htmlFor="difficulty" className="form-label">Difficulty (1-5)</label>
                  <input
                    type="number"
                    className="form-control"
                    id="difficulty"
                    value={difficulty}
                    onChange={(e) => setDifficulty(e.target.value)}
                    min="1"
                    max="5"
                  />
                </div>
              </div>
              <div className="mt-3">
                <label htmlFor="targetDate" className="form-label">Target Date</label>
                <input
                  type="date"
                  className="form-control"
                  id="targetDate"
                  value={targetDate}
                  onChange={(e) => setTargetDate(e.target.value)}
                  required
                />
              </div>
            </form>
          </div>
          <div className="modal-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>Close</button>
            <button type="button" className="btn btn-primary" onClick={handleAdd}>Save Document</button>
          </div>
        </div>
      </div>
    </div>
  );
}
