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
  const [editShortName, setEditShortName] = useState('');
  const [editContent, setEditContent] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [isLinking, setIsLinking] = useState(false);
  const [linkTargetId, setLinkTargetId] = useState('');
  
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
      setEditShortName(concept.shortName || '');
      setEditContent(concept.content);
      setIsEditing(false);
      setIsLinking(false);
    }
  }, [data]);

  const handleCreateNode = () => {
    const newNode: ConceptNode = {
      id: Date.now().toString(),
      title: 'New Concept',
      shortName: 'Concept',
      content: 'Write your notes here...\n\n### Math\n$$ E = mc^2 $$\n\n### Chemistry\n$$ \\ce{H2O + CO2 -> H2CO3} $$',
    };
    const newData = { ...data, nodes: [...data.nodes, newNode] };
    saveData(newData);
    setSelectedNode(newNode);
    setEditTitle(newNode.title);
    setEditShortName(newNode.shortName || '');
    setEditContent(newNode.content);
    setIsEditing(true);
    setIsLinking(false);
  };

  const handleSaveNode = () => {
    if (!selectedNode) return;
    const newData = {
      ...data,
      nodes: data.nodes.map(n => n.id === selectedNode.id ? { ...n, title: editTitle, shortName: editShortName, content: editContent } : n)
    };
    saveData(newData);
    setIsEditing(false);
    setSelectedNode({ ...selectedNode, title: editTitle, shortName: editShortName, content: editContent });
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
    setIsLinking(true);
  };

  const confirmLink = () => {
    if (!selectedNode || !linkTargetId) return;
    
    const targetNode = data.nodes.find(n => n.id === linkTargetId);
    if (!targetNode) return;

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
    setIsLinking(false);
    setLinkTargetId('');
  };

  const renderNode = useCallback((node: any, ctx: CanvasRenderingContext2D, globalScale: number) => {
    const isSelected = node.id === selectedNode?.id;
    const label = node.shortName || node.title;
    const fontSize = 12 / globalScale;
    ctx.font = `${fontSize}px Sans-Serif`;
    
    // Draw circle
    ctx.beginPath();
    ctx.arc(node.x, node.y, 6, 0, 2 * Math.PI, false);
    ctx.fillStyle = isSelected ? '#a882ff' : '#666666';
    ctx.fill();
    
    // Draw text
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#e0e0e0';
    ctx.fillText(label, node.x, node.y + 8 + fontSize);
  }, [selectedNode]);

  const filteredData = {
    nodes: data.nodes.filter(n => n.title.toLowerCase().includes(searchQuery.toLowerCase())),
    links: data.links
  };

  return (
    <div className="row h-100 rounded shadow-sm overflow-hidden border border-secondary">
      <div className="col-md-8 position-relative p-0 h-100" ref={containerRef} style={{ backgroundColor: '#1e1e1e' }}>
        <div className="position-absolute top-0 start-0 p-3 z-3 w-100 d-flex justify-content-between align-items-center" style={{ pointerEvents: 'none' }}>
          <div style={{ pointerEvents: 'auto' }} className="d-flex gap-2">
            <button className="btn btn-outline-light shadow-sm rounded-pill px-3 fw-bold" onClick={handleCreateNode}>
              <FaPlus className="me-2" /> New Concept
            </button>
          </div>
          <div style={{ pointerEvents: 'auto', width: '300px' }}>
            <div className="input-group shadow-sm">
              <span className="input-group-text bg-dark border-secondary text-light border-end-0"><FaSearch /></span>
              <input 
                type="text" 
                className="form-control bg-dark border-secondary text-light border-start-0 ps-0" 
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
          backgroundColor="#1e1e1e"
          nodeCanvasObject={renderNode}
          nodeRelSize={8}
          linkColor={() => '#444444'}
          linkWidth={2}
          onNodeClick={handleNodeClick}
          width={dimensions.width}
          height={dimensions.height}
        />
      </div>
      
      <div className="col-md-4 h-100 d-flex flex-column bg-dark text-light border-start border-secondary p-0">
        {selectedNode ? (
          <>
            <div className="p-3 border-bottom border-secondary d-flex justify-content-between align-items-center" style={{ backgroundColor: '#252526' }}>
              <h5 className="mb-0 text-truncate fw-bold" style={{maxWidth: '200px'}}>
                {isEditing ? 'Editing Concept' : selectedNode.title}
              </h5>
              <div className="btn-group">
                {!isEditing ? (
                  <>
                    <button className="btn btn-sm btn-outline-light" onClick={() => setIsEditing(true)}>Edit</button>
                    <button className="btn btn-sm btn-outline-primary" onClick={handleCreateLink} title="Link to another concept"><FaLink /></button>
                    <button className="btn btn-sm btn-outline-danger" onClick={handleDeleteNode}><FaTrash /></button>
                  </>
                ) : (
                  <>
                    <button className="btn btn-sm btn-primary" onClick={handleSaveNode}><FaSave className="me-1"/> Save</button>
                    <button className="btn btn-sm btn-outline-secondary" onClick={() => {
                      setIsEditing(false);
                      setEditTitle(selectedNode.title);
                      setEditShortName(selectedNode.shortName || '');
                      setEditContent(selectedNode.content);
                    }}>Cancel</button>
                  </>
                )}
              </div>
            </div>

            {isLinking && (
              <div className="p-3 border-bottom border-secondary bg-dark d-flex flex-column">
                <small className="text-muted mb-2">Select a concept to link with:</small>
                <div className="d-flex">
                  <select className="form-select form-select-sm bg-dark text-light border-secondary" value={linkTargetId} onChange={e => setLinkTargetId(e.target.value)}>
                    <option value="">-- Select Concept --</option>
                    {data.nodes.filter(n => n.id !== selectedNode.id).map(n => (
                      <option key={n.id} value={n.id}>{n.title}</option>
                    ))}
                  </select>
                  <button className="btn btn-sm btn-primary ms-2" onClick={confirmLink}>Link</button>
                  <button className="btn btn-sm btn-outline-secondary ms-1" onClick={() => setIsLinking(false)}>Cancel</button>
                </div>
              </div>
            )}
            
            <div className="flex-grow-1 p-4" style={{ overflowY: 'auto', backgroundColor: '#1e1e1e' }}>
              {isEditing ? (
                <div className="d-flex flex-column h-100 gap-3">
                  <input 
                    type="text" 
                    className="form-control bg-dark text-light border-secondary fw-bold fs-5" 
                    value={editTitle} 
                    onChange={e => setEditTitle(e.target.value)} 
                    placeholder="Full Concept Title"
                  />
                  <input 
                    type="text" 
                    className="form-control bg-dark text-light border-secondary" 
                    value={editShortName} 
                    onChange={e => setEditShortName(e.target.value)} 
                    placeholder="Short Label (shown on graph)"
                  />
                  <textarea 
                    className="form-control bg-dark text-light border-secondary flex-grow-1 font-monospace" 
                    value={editContent} 
                    onChange={e => setEditContent(e.target.value)}
                    placeholder="Write your notes in Markdown. Use $$ for Math and \ce{} for Chemistry."
                    style={{ resize: 'none' }}
                  />
                </div>
              ) : (
                <div className="markdown-body" style={{ fontSize: '1.1rem', lineHeight: '1.6', color: '#e0e0e0' }}>
                  <ReactMarkdown 
                    remarkPlugins={[remarkMath]} 
                    rehypePlugins={[[rehypeKatex, { strict: false, trust: true }]]}
                  >
                    {selectedNode.content}
                  </ReactMarkdown>
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="h-100 d-flex flex-column justify-content-center align-items-center text-muted p-4 text-center" style={{ backgroundColor: '#1e1e1e' }}>
            <div className="display-1 mb-3 opacity-25">🧠</div>
            <h4 className="fw-bold">Knowledge Graph</h4>
            <p className="px-4">Select a node from the graph to view its details, or create a new concept to start building your knowledge base.</p>
          </div>
        )}
      </div>
    </div>
  );
}
