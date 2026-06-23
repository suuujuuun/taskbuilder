import { useState, useEffect, useRef, useCallback } from 'react';
import ForceGraph2D from 'react-force-graph-2d';
import ReactMarkdown from 'react-markdown';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import 'katex/dist/katex.min.css';
import { FaPlus, FaSave, FaTrash, FaLink, FaSearch } from 'react-icons/fa';
import type { ConceptData, ConceptNode } from './types';

export default function KnowledgeGraphPage() {
  const [data, setData] = useState<ConceptData>({ nodes: [], links: [] });
  const [selectedNode, setSelectedNode] = useState<ConceptNode | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState('');
  const [editContent, setEditContent] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const graphRef = useRef<any>();
  const containerRef = useRef<HTMLDivElement>(null);
  const [dimensions, setDimensions] = useState({ width: 800, height: 600 });

  useEffect(() => {
    window.api.getConcepts().then(setData);
  }, []);

  useEffect(() => {
    const updateDimensions = () => {
      if (containerRef.current) {
        setDimensions({
          width: containerRef.current.clientWidth,
          height: containerRef.current.clientHeight
        });
      }
    };
    updateDimensions();
    window.addEventListener('resize', updateDimensions);
    return () => window.removeEventListener('resize', updateDimensions);
  }, []);

  const saveData = async (newData: ConceptData) => {
    setData(newData);
    await window.api.saveConcepts(newData);
  };

  const handleNodeClick = useCallback((node: ConceptNode) => {
    const concept = data.nodes.find(n => n.id === node.id);
    if (concept) {
      setSelectedNode(concept);
      setEditTitle(concept.title);
      setEditContent(concept.content);
      setIsEditing(false);
    }
  }, [data]);

  const handleCreateNode = () => {
    const newNode: ConceptNode = {
      id: Date.now().toString(),
      title: 'New Concept',
      content: 'Write your notes here...\n\n### Math\n$$ E = mc^2 $$\n\n### Chemistry\n$$ \\ce{H2O + CO2 -> H2CO3} $$',
    };
    const newData = { ...data, nodes: [...data.nodes, newNode] };
    saveData(newData);
    setSelectedNode(newNode);
    setEditTitle(newNode.title);
    setEditContent(newNode.content);
    setIsEditing(true);
  };

  const handleSaveNode = () => {
    if (!selectedNode) return;
    const newData = {
      ...data,
      nodes: data.nodes.map(n => n.id === selectedNode.id ? { ...n, title: editTitle, content: editContent } : n)
    };
    saveData(newData);
    setIsEditing(false);
    setSelectedNode({ ...selectedNode, title: editTitle, content: editContent });
  };

  const handleDeleteNode = () => {
    if (!selectedNode) return;
    if (!confirm('Are you sure you want to delete this concept?')) return;
    
    const newData = {
      nodes: data.nodes.filter(n => n.id !== selectedNode.id),
      links: data.links.filter(l => l.source !== selectedNode.id && l.target !== selectedNode.id)
    };
    saveData(newData);
    setSelectedNode(null);
  };

  const handleCreateLink = () => {
    if (!selectedNode) return;
    const targetId = prompt('Enter the exact Title of the concept to link to:');
    if (!targetId) return;
    
    const targetNode = data.nodes.find(n => n.title.toLowerCase() === targetId.toLowerCase());
    if (!targetNode) {
      alert('Concept not found!');
      return;
    }
    if (targetNode.id === selectedNode.id) {
      alert('Cannot link to itself.');
      return;
    }
    
    const linkExists = data.links.some(l => 
      (l.source === selectedNode.id && l.target === targetNode.id) ||
      (l.source === targetNode.id && l.target === selectedNode.id)
    );
    
    if (linkExists) {
      alert('Link already exists.');
      return;
    }

    const newLink = { source: selectedNode.id, target: targetNode.id };
    saveData({ ...data, links: [...data.links, newLink] });
  };

  const filteredData = {
    nodes: data.nodes.filter(n => n.title.toLowerCase().includes(searchQuery.toLowerCase())),
    links: data.links
  };

  return (
    <div className="row h-100 rounded shadow-sm overflow-hidden border">
      <div className="col-md-8 position-relative p-0 h-100 bg-white" ref={containerRef}>
        <div className="position-absolute top-0 start-0 p-3 z-3 w-100 d-flex justify-content-between align-items-center" style={{ pointerEvents: 'none' }}>
          <div style={{ pointerEvents: 'auto' }} className="d-flex gap-2">
            <button className="btn btn-primary shadow-sm rounded-pill px-3 fw-bold" onClick={handleCreateNode}>
              <FaPlus className="me-2" /> New Concept
            </button>
          </div>
          <div style={{ pointerEvents: 'auto', width: '300px' }}>
            <div className="input-group shadow-sm">
              <span className="input-group-text bg-white border-end-0"><FaSearch className="text-muted"/></span>
              <input 
                type="text" 
                className="form-control border-start-0 ps-0" 
                placeholder="Search concepts..." 
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
          </div>
        </div>
        
        <ForceGraph2D
          ref={graphRef}
          graphData={filteredData}
          nodeLabel="title"
          nodeColor={(node: ConceptNode) => node.id === selectedNode?.id ? '#ffc107' : '#0d6efd'}
          nodeRelSize={8}
          linkColor={() => '#adb5bd'}
          linkWidth={2}
          onNodeClick={handleNodeClick}
          width={dimensions.width}
          height={dimensions.height}
        />
      </div>
      
      <div className="col-md-4 h-100 d-flex flex-column bg-light border-start p-0">
        {selectedNode ? (
          <>
            <div className="p-3 border-bottom d-flex justify-content-between align-items-center bg-white">
              <h5 className="mb-0 text-truncate fw-bold text-dark" style={{maxWidth: '200px'}}>
                {isEditing ? 'Editing Concept' : selectedNode.title}
              </h5>
              <div className="btn-group">
                {!isEditing ? (
                  <>
                    <button className="btn btn-sm btn-outline-primary" onClick={() => setIsEditing(true)}>Edit</button>
                    <button className="btn btn-sm btn-outline-success" onClick={handleCreateLink} title="Link to another concept"><FaLink /></button>
                    <button className="btn btn-sm btn-outline-danger" onClick={handleDeleteNode}><FaTrash /></button>
                  </>
                ) : (
                  <>
                    <button className="btn btn-sm btn-primary" onClick={handleSaveNode}><FaSave className="me-1"/> Save</button>
                    <button className="btn btn-sm btn-outline-secondary" onClick={() => {
                      setIsEditing(false);
                      setEditTitle(selectedNode.title);
                      setEditContent(selectedNode.content);
                    }}>Cancel</button>
                  </>
                )}
              </div>
            </div>
            
            <div className="flex-grow-1 p-4" style={{ overflowY: 'auto' }}>
              {isEditing ? (
                <div className="d-flex flex-column h-100 gap-3">
                  <input 
                    type="text" 
                    className="form-control fw-bold fs-5" 
                    value={editTitle} 
                    onChange={e => setEditTitle(e.target.value)} 
                    placeholder="Concept Title"
                  />
                  <textarea 
                    className="form-control flex-grow-1 font-monospace" 
                    value={editContent} 
                    onChange={e => setEditContent(e.target.value)}
                    placeholder="Write your notes in Markdown. Use $$ for Math and \ce{} for Chemistry."
                    style={{ resize: 'none' }}
                  />
                </div>
              ) : (
                <div className="markdown-body" style={{ fontSize: '1.1rem', lineHeight: '1.6' }}>
                  <ReactMarkdown 
                    remarkPlugins={[remarkMath]} 
                    rehypePlugins={[rehypeKatex]}
                  >
                    {selectedNode.content}
                  </ReactMarkdown>
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="h-100 d-flex flex-column justify-content-center align-items-center text-muted p-4 text-center bg-white">
            <div className="display-1 mb-3 opacity-50">🧠</div>
            <h4 className="fw-bold">Knowledge Graph</h4>
            <p className="px-4">Select a node from the graph to view its details, or create a new concept to start building your knowledge base.</p>
          </div>
        )}
      </div>
    </div>
  );
}
