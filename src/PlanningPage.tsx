import { useState, useEffect } from 'react';
import type { Todo } from './types';
import { FaTrash, FaPlus, FaCheckCircle, FaRegCircle } from 'react-icons/fa';

export function PlanningPage() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [memo, setMemo] = useState<string>('');
  const [newTodoText, setNewTodoText] = useState('');

  useEffect(() => {
    window.api.getTodos().then(setTodos);
    window.api.getMemo().then(setMemo);
  }, []);

  const handleAddTodo = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTodoText.trim()) return;

    const newTodo: Todo = {
      id: Date.now(),
      text: newTodoText.trim(),
      completed: false
    };

    const updatedTodos = [...todos, newTodo];
    setTodos(updatedTodos);
    setNewTodoText('');
    window.api.saveTodos(updatedTodos);
  };

  const toggleTodo = (id: number) => {
    const updatedTodos = todos.map(t => t.id === id ? { ...t, completed: !t.completed } : t);
    setTodos(updatedTodos);
    window.api.saveTodos(updatedTodos);
  };

  const deleteTodo = (id: number) => {
    const updatedTodos = todos.filter(t => t.id !== id);
    setTodos(updatedTodos);
    window.api.saveTodos(updatedTodos);
  };

  const handleMemoChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newMemo = e.target.value;
    setMemo(newMemo);
    window.api.saveMemo(newMemo); // Auto-saves on every keystroke (we could debounce this, but local IPC is very fast)
  };

  return (
    <div className="row h-100 p-4">
      {/* To-Do List Section */}
      <div className="col-md-5 d-flex flex-column border-end h-100">
        <h2 className="mb-4">To-Do List</h2>
        
        <form onSubmit={handleAddTodo} className="mb-4 d-flex">
          <input 
            type="text" 
            className="form-control bg-dark text-light border-secondary me-2" 
            placeholder="Add a new task..." 
            value={newTodoText}
            onChange={(e) => setNewTodoText(e.target.value)}
          />
          <button type="submit" className="btn btn-primary" disabled={!newTodoText.trim()}>
            <FaPlus />
          </button>
        </form>

        <div className="flex-grow-1" style={{ overflowY: 'auto' }}>
          <ul className="list-group list-group-flush bg-transparent">
            {todos.map(todo => (
              <li key={todo.id} className="list-group-item bg-transparent text-light d-flex justify-content-between align-items-center border-secondary">
                <div 
                  className="d-flex align-items-center flex-grow-1" 
                  style={{ cursor: 'pointer', opacity: todo.completed ? 0.6 : 1 }}
                  onClick={() => toggleTodo(todo.id)}
                >
                  <span className="me-3 fs-5 text-primary">
                    {todo.completed ? <FaCheckCircle /> : <FaRegCircle />}
                  </span>
                  <span style={{ textDecoration: todo.completed ? 'line-through' : 'none' }}>
                    {todo.text}
                  </span>
                </div>
                <button 
                  className="btn btn-sm btn-outline-danger ms-2 border-0" 
                  onClick={(e) => { e.stopPropagation(); deleteTodo(todo.id); }}
                >
                  <FaTrash />
                </button>
              </li>
            ))}
            {todos.length === 0 && (
              <div className="text-muted text-center mt-4">No tasks yet.</div>
            )}
          </ul>
        </div>
      </div>

      {/* Global Memo Section */}
      <div className="col-md-7 d-flex flex-column h-100 ps-4">
        <h2 className="mb-4">Global Memo</h2>
        <textarea 
          className="form-control bg-dark text-light border-secondary flex-grow-1 p-3" 
          placeholder="Jot down your notes, ideas, or references here..."
          value={memo}
          onChange={handleMemoChange}
          style={{ resize: 'none' }}
        />
        <div className="text-muted small mt-2 text-end">Auto-saved</div>
      </div>
    </div>
  );
}
