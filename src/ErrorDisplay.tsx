interface ErrorDisplayProps {
  message: string | null;
  onDismiss: () => void;
}

export function ErrorDisplay({ message, onDismiss }: ErrorDisplayProps) {
  if (!message) return null;

  return (
    <div 
      className="alert alert-danger alert-dismissible fade show" 
      role="alert"
      style={{
        position: 'fixed',
        bottom: '20px',
        right: '20px',
        zIndex: 1050, // Ensure it's above other elements
      }}
    >
      <strong>Error:</strong> {message}
      <button 
        type="button" 
        className="btn-close" 
        onClick={onDismiss}
        aria-label="Close"
      ></button>
    </div>
  );
}
