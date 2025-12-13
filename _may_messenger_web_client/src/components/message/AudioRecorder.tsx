import { useState, useEffect, useRef } from 'react';
import { X, Send } from 'lucide-react';
import { audioRecorder } from '../../services/audioRecorder';
import { formatDuration } from '../../utils/formatters';

interface AudioRecorderProps {
  onSend: (audioBlob: Blob) => void;
  onCancel: () => void;
}

export const AudioRecorder = ({ onSend, onCancel }: AudioRecorderProps) => {
  const [duration, setDuration] = useState(0);
  const intervalRef = useRef<number>();

  useEffect(() => {
    startRecording();
    
    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, []);

  const startRecording = async () => {
    try {
      await audioRecorder.startRecording();
      
      // Start duration counter
      intervalRef.current = window.setInterval(() => {
        setDuration((prev) => prev + 1);
      }, 1000);
    } catch (error) {
      console.error('Failed to start recording', error);
      alert('Не удалось получить доступ к микрофону');
      onCancel();
    }
  };

  const handleSend = async () => {
    try {
      const audioBlob = await audioRecorder.stopRecording();
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
      onSend(audioBlob);
    } catch (error) {
      console.error('Failed to stop recording', error);
    }
  };

  const handleCancel = () => {
    audioRecorder.cancelRecording();
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
    }
    onCancel();
  };

  return (
    <div className="flex items-center gap-3 px-4 py-3 bg-red-50 border-t border-red-200">
      <button
        onClick={handleCancel}
        className="p-2 rounded-full hover:bg-red-100 transition"
      >
        <X className="w-6 h-6 text-red-600" />
      </button>
      
      <div className="flex-1 flex items-center gap-3">
        <div className="w-3 h-3 bg-red-600 rounded-full animate-pulse"></div>
        
        <div className="flex-1">
          <div className="text-sm font-medium text-gray-700">
            Запись голосового сообщения...
          </div>
          <div className="text-xs text-gray-500">
            {formatDuration(duration)}
          </div>
        </div>
      </div>
      
      <button
        onClick={handleSend}
        className="p-2 rounded-full bg-indigo-600 hover:bg-indigo-700 transition"
      >
        <Send className="w-6 h-6 text-white" />
      </button>
    </div>
  );
};
