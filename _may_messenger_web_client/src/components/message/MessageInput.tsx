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
    <form onSubmit={handleSubmit} className="flex items-center gap-2 px-4 py-3 border-t border-gray-200 bg-white">
      <input
        type="text"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Введите сообщение..."
        disabled={disabled}
        className="flex-1 px-4 py-2 border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-indigo-500 disabled:opacity-50"
      />
      
      {text.trim() ? (
        <button
          type="submit"
          disabled={disabled}
          className="p-2 rounded-full bg-indigo-600 hover:bg-indigo-700 text-white disabled:opacity-50 disabled:cursor-not-allowed transition"
        >
          <Send className="w-6 h-6" />
        </button>
      ) : (
        <button
          type="button"
          onClick={handleStartRecording}
          disabled={disabled}
          className="p-2 rounded-full bg-indigo-600 hover:bg-indigo-700 text-white disabled:opacity-50 disabled:cursor-not-allowed transition"
        >
          <Mic className="w-6 h-6" />
        </button>
      )}
    </form>
  );
};
