import { useRef } from 'react';
import { useDrag, useDrop, XYCoord } from 'react-dnd';
import type { Document } from './types';

const ItemType = 'CARD';

interface DraggableDocumentCardProps {
  doc: Document;
  index: number;
  moveCard: (dragIndex: number, hoverIndex: number) => void;
}

interface DragItem {
  index: number;
  id: string;
  type: string;
}

const getLatestLog = (doc: Document) => {
    if (!doc || doc.progressLogs.length === 0) return null;
    return doc.progressLogs[doc.progressLogs.length - 1];
};

export function DraggableDocumentCard({ doc, index, moveCard }: DraggableDocumentCardProps) {
  const ref = useRef<HTMLDivElement>(null);
  
  const [, drop] = useDrop({
    accept: ItemType,
    hover(item: DragItem, monitor) {
      if (!ref.current) {
        return;
      }
      const dragIndex = item.index;
      const hoverIndex = index;
      if (dragIndex === hoverIndex) {
        return;
      }
      const hoverBoundingRect = ref.current?.getBoundingClientRect();
      const hoverMiddleY = (hoverBoundingRect.bottom - hoverBoundingRect.top) / 2;
      const clientOffset = monitor.getClientOffset();
      const hoverClientY = (clientOffset as XYCoord).y - hoverBoundingRect.top;
      if (dragIndex < hoverIndex && hoverClientY < hoverMiddleY) {
        return;
      }
      if (dragIndex > hoverIndex && hoverClientY > hoverMiddleY) {
        return;
      }
      moveCard(dragIndex, hoverIndex);
      item.index = hoverIndex;
    },
  });

  const [{ isDragging }, drag] = useDrag({
    type: ItemType,
    item: () => ({ id: String(doc.id), index }),
    collect: (monitor) => ({
      isDragging: monitor.isDragging(),
    }),
  });

  const opacity = isDragging ? 0 : 1;
  drag(drop(ref));

  const latestLog = getLatestLog(doc);
  const currentPage = latestLog?.page ?? 0;
  const progress = Math.round((currentPage / doc.totalPages) * 100);

  return (
    <div ref={ref} style={{ opacity }} className="col h-100">
        <div className="card h-100">
            <div className="card-body d-flex flex-column">
                <div className="d-flex justify-content-between align-items-start">
                  <h5 className="card-title">{doc.title}</h5>
                  {/* Add the Open button here */}
                  {doc.link && (
                    <button 
                      className="btn btn-sm btn-primary py-0 px-2"
                      onClick={(e) => {
                        e.stopPropagation(); // Prevent drag events
                        window.api.openLink(doc.link!);
                      }}
                    >
                      Open File
                    </button>
                  )}
                </div>
                <p className="card-text text-muted small">
                Target: {new Date(doc.targetDate).toLocaleDateString()}
                </p>
                <div className="mt-auto">
                <div className="d-flex justify-content-between">
                    <small>{currentPage} / {doc.totalPages} pages</small>
                    <small>{progress}%</small>
                </div>
                <div className="progress">
                    <div 
                    className="progress-bar" 
                    role="progressbar" 
                    style={{ width: `${progress}%` }}
                    ></div>
                </div>
                </div>
            </div>
        </div>
    </div>
  );
}
