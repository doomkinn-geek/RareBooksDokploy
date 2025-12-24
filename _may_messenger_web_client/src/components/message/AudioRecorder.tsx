import { useState, useEffect, useRef } from 'react';
import { X, Send, Mic, ChevronLeft } from 'lucide-react';
import { audioRecorder } from '../../services/audioRecorder';
import { formatDuration } from '../../utils/formatters';

interface AudioRecorderProps {
  onSend: (audioBlob: Blob) => void;
  onCancel: () => void;
}

// Simple audio visualizer bars
const AudioWaveform = () => {
  const [bars, setBars] = useState<number[]>([0.3, 0.5, 0.7, 0.4, 0.8, 0.5, 0.6, 0.3, 0.7, 0.5, 0.4, 0.8]);
  
  useEffect(() => {
    const interval = setInterval(() => {
      setBars(prev => prev.map(() => 0.2 + Math.random() * 0.8));
    }, 100);
    
    return () => clearInterval(interval);
  }, []);
  
  return (
    <div className="flex items-center gap-0.5 h-8">
      {bars.map((height, i) => (
        <div
          key={i}
          className="w-1 bg-red-500 rounded-full transition-all duration-100"
          style={{ height: `${height * 100}%` }}
        />
      ))}
    </div>
  );
};

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
    <div className="flex items-center gap-3 px-4 py-3 bg-gradient-to-r from-red-50 to-indigo-50 border-t border-red-200">
      {/* Cancel hint */}
      <div className="flex items-center gap-1 text-gray-500">
        <ChevronLeft className="w-4 h-4" />
        <span className="text-xs">Отмена</span>
      </div>
      
      <button
        onClick={handleCancel}
        className="p-2 rounded-full bg-red-100 hover:bg-red-200 transition"
        title="Отменить запись"
      >
        <X className="w-5 h-5 text-red-600" />
      </button>
      
      <div className="flex-1 flex items-center gap-3">
        {/* Recording indicator */}
        <div className="relative">
          <Mic className="w-5 h-5 text-red-600" />
          <span className="absolute -top-1 -right-1 w-2 h-2 bg-red-600 rounded-full animate-ping" />
        </div>
        
        {/* Audio waveform */}
        <div className="flex-1">
          <AudioWaveform />
        </div>
        
        {/* Duration */}
        <div className="flex flex-col items-center">
          <div className="text-lg font-mono font-medium text-red-600">
            {formatDuration(duration)}
          </div>
          <div className="text-xs text-gray-500">REC</div>
        </div>
      </div>
      
      <button
        onClick={handleSend}
        className="p-3 rounded-full bg-indigo-600 hover:bg-indigo-700 transition shadow-lg"
        title="Отправить"
      >
        <Send className="w-5 h-5 text-white" />
      </button>
    </div>
  );
};
