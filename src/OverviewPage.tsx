import { useState, useCallback, useEffect } from 'react';
import type { Document } from './types';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { DraggableDocumentCard } from './DraggableDocumentCard';

interface OverviewPageProps {
  documents: Document[];
  onOrderChange: (orderedDocs: Document[]) => void;
}

export function OverviewPage({ documents, onOrderChange }: OverviewPageProps) {
  const [orderedDocs, setOrderedDocs] = useState(documents);
  const [hasOrderChanged, setHasOrderChanged] = useState(false);

  useEffect(() => {
    setOrderedDocs(documents);
  }, [documents]);

  const moveCard = useCallback((dragIndex: number, hoverIndex: number) => {
    const dragCard = orderedDocs[dragIndex];
    const newDocs = [...orderedDocs];
    newDocs.splice(dragIndex, 1);
    newDocs.splice(hoverIndex, 0, dragCard);
    setOrderedDocs(newDocs);
    setHasOrderChanged(true);
  }, [orderedDocs]);

  const handleSaveOrder = () => {
    onOrderChange(orderedDocs);
    setHasOrderChanged(false);
  }

  const renderCard = (doc: Document, index: number) => {
    return (
      <DraggableDocumentCard
        key={doc.id}
        index={index}
        doc={doc}
        moveCard={moveCard}
      />
    );
  };

  // 통계 계산 로직
  const totalBooks = documents.length;
  const totalPages = documents.reduce((sum, doc) => sum + doc.totalPages, 0);
  const totalRead = documents.reduce((sum, doc) => {
    const logs = doc.progressLogs || [];
    const lastPage = logs.length > 0 ? logs[logs.length - 1].page : 0;
    return sum + lastPage;
  }, 0);
  const overallProgress = totalPages > 0 ? Math.round((totalRead / totalPages) * 100) : 0;

  return (
    <DndProvider backend={HTML5Backend}>
      <div className="col-12 p-4" style={{ overflowY: 'auto', height: '100%' }}>
          
        {/* --- 1. 상단 통계 대시보드 --- */}
        <div className="row mb-5 g-3">
          <div className="col-md-4">
            <div className="card h-100" style={{ backgroundColor: '#2f2f38', borderLeft: '4px solid var(--primary-color)' }}>
              <div className="card-body">
                <div className="text-muted mb-1 small text-uppercase fw-bold">Total Books</div>
                <h2 className="mb-0">{totalBooks}</h2>
              </div>
            </div>
          </div>
          <div className="col-md-4">
            <div className="card h-100" style={{ backgroundColor: '#2f2f38', borderLeft: '4px solid var(--success-color)' }}>
              <div className="card-body">
                <div className="text-muted mb-1 small text-uppercase fw-bold">Pages Read</div>
                <h2 className="mb-0">{totalRead} <span className="text-muted fs-5">/ {totalPages}</span></h2>
              </div>
            </div>
          </div>
          <div className="col-md-4">
            <div className="card h-100" style={{ backgroundColor: '#2f2f38', borderLeft: '4px solid var(--danger-color)' }}>
              <div className="card-body">
                <div className="text-muted mb-1 small text-uppercase fw-bold">Global Progress</div>
                <h2 className="mb-0">{overallProgress}%</h2>
              </div>
            </div>
          </div>
        </div>

        {/* --- 2. 라이브러리 컨트롤 --- */}
        <div className='d-flex justify-content-between align-items-center mb-4'>
          <h2 className="mb-0">Library Overview</h2>
          <button 
            className='btn btn-success' 
            disabled={!hasOrderChanged}
            onClick={handleSaveOrder}
          >
            Save Custom Order
          </button>
        </div>
        
        {/* --- 3. 남은 공간을 꽉 채우는 CSS 그리드 --- */}
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', 
          gap: '1.5rem', 
          width: '100%',
          alignItems: 'stretch'
        }}>
          {orderedDocs.map((doc, i) => renderCard(doc, i))}
        </div>
          
      </div>
    </DndProvider>
  );
}
