import { useState } from 'react';
import { Send, Mic } from 'lucide-react';
import { AudioRecorder } from './AudioRecorder';

interface MessageInputProps {
  onSendText: (text: string) => void;
  onSendAudio: (audioBlob: Blob) => void;
  disabled?: boolean;
}

export const MessageInput = ({ onSendText, onSendAudio, disabled }: MessageInputProps) => {
  const [text, setText] = useState('');
  const [isRecording, setIsRecording] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (text.trim() && !disabled) {
      onSendText(text.trim());
      setText('');
    }
  };

  const handleStartRecording = () => {
    setIsRecording(true);
  };

  const handleSendAudio = (audioBlob: Blob) => {
    setIsRecording(false);
    onSendAudio(audioBlob);
  };

  const handleCancelRecording = () => {
    setIsRecording(false);
  };

  if (isRecording) {
    return <AudioRecorder onSend={handleSendAudio} onCancel={handleCancelRecording} />;
  }

  return (
    <form onSubmit={handleSubmit} className="flex items-center gap-3 px-6 py-4 border-t border-gray-200 bg-white">
      <input
        type="text"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Напишите сообщение..."
        disabled={disabled}
        className="flex-1 px-5 py-3 border border-gray-200 bg-gray-50 rounded-full focus:outline-none focus:ring-2 focus:ring-indigo-500/50 focus:bg-white focus:border-indigo-200 transition-all placeholder:text-gray-400 disabled:opacity-50"
      />
      
      {text.trim() ? (
        <button
          type="submit"
          disabled={disabled}
          className="p-3 rounded-full bg-gradient-to-r from-indigo-600 to-indigo-700 hover:from-indigo-700 hover:to-indigo-800 text-white shadow-md disabled:opacity-50 disabled:shadow-none disabled:cursor-not-allowed transform hover:scale-105 transition-all duration-200"
        >
          <Send className="w-5 h-5" />
        </button>
      ) : (
        <button
          type="button"
          onClick={handleStartRecording}
          disabled={disabled}
          className="p-3 rounded-full bg-indigo-50 hover:bg-indigo-100 text-indigo-600 shadow-sm hover:shadow-md disabled:opacity-50 disabled:shadow-none disabled:cursor-not-allowed transform hover:scale-105 transition-all duration-200"
        >
          <Mic className="w-5 h-5" />
        </button>
      )}
    </form>
  );
};
