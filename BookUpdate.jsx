import React, { useEffect } from 'react';

const BookUpdate = () => {
  useEffect(() => {
    const intervalId = setInterval(() => {
      fetchUpdateStatus();
    }, 5000);
    
    const handleVisibilityChange = () => {
      if (document.hidden) {
        clearInterval(intervalId);
      } else {
        clearInterval(intervalId);
        const newIntervalId = setInterval(() => {
          fetchUpdateStatus();
        }, 5000);
        return () => clearInterval(newIntervalId);
      }
    };
    
    document.addEventListener('visibilitychange', handleVisibilityChange);
    
    return () => {
      clearInterval(intervalId);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  return (
    // Rest of the component code
  );
};

export default BookUpdate; 