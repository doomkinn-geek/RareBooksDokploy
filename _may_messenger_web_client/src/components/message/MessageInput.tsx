import { useState, useRef } from 'react';
import { Send, Mic } from 'lucide-react';
import { AudioRecorder } from './AudioRecorder';
import { signalRService } from '../../services/signalRService';
import { useChatStore } from '../../stores/chatStore';

interface MessageInputProps {
  onSendText: (text: string) => void;
  onSendAudio: (audioBlob: Blob) => void;
  disabled?: boolean;
}

export const MessageInput = ({ onSendText, onSendAudio, disabled }: MessageInputProps) => {
  const [text, setText] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const typingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isTypingRef = useRef(false);
  const { selectedChatId } = useChatStore();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (text.trim() && !disabled) {
      onSendText(text.trim());
      setText('');
      
      // Stop typing indicator
      if (isTypingRef.current && selectedChatId) {
        signalRService.sendTypingIndicator(selectedChatId, false);
        isTypingRef.current = false;
      }
    }
  };

  const handleTextChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setText(e.target.value);

    // Send typing indicator
    if (selectedChatId && signalRService.isConnected) {
      if (!isTypingRef.current) {
        signalRService.sendTypingIndicator(selectedChatId, true);
        isTypingRef.current = true;
      }

      // Clear existing timeout
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }

      // Set new timeout to stop typing indicator after 2 seconds of inactivity
      typingTimeoutRef.current = setTimeout(() => {
        if (isTypingRef.current) {
          signalRService.sendTypingIndicator(selectedChatId, false);
          isTypingRef.current = false;
        }
      }, 2000);
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
        onChange={handleTextChange}
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
