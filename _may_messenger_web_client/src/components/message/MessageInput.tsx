import { useState, useRef } from 'react';
import { Send, Mic, Image as ImageIcon, X } from 'lucide-react';
import { AudioRecorder } from './AudioRecorder';
import { signalRService } from '../../services/signalRService';
import { useChatStore } from '../../stores/chatStore';

interface MessageInputProps {
  onSendText: (text: string) => void;
  onSendAudio: (audioBlob: Blob) => void;
  onSendImage?: (imageFile: File) => void;
  disabled?: boolean;
}

export const MessageInput = ({ onSendText, onSendAudio, onSendImage, disabled }: MessageInputProps) => {
  const [text, setText] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const typingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isTypingRef = useRef(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
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

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file && file.type.startsWith('image/')) {
      if (file.size > 10 * 1024 * 1024) { // 10MB limit
        alert('Изображение слишком большое. Максимум 10MB');
        return;
      }
      setSelectedImage(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setImagePreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
    // Reset input
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleSendImage = () => {
    if (selectedImage && onSendImage) {
      onSendImage(selectedImage);
      setSelectedImage(null);
      setImagePreview(null);
    }
  };

  const handleCancelImage = () => {
    setSelectedImage(null);
    setImagePreview(null);
  };

  if (isRecording) {
    return <AudioRecorder onSend={handleSendAudio} onCancel={handleCancelRecording} />;
  }

  // Image preview mode
  if (selectedImage && imagePreview) {
    return (
      <div className="px-4 py-3 border-t border-gray-200 bg-white">
        <div className="flex flex-col gap-2">
          <div className="relative w-full max-w-xs">
            <img
              src={imagePreview}
              alt="Предпросмотр"
              className="w-full h-auto rounded-lg border border-gray-300"
            />
            <button
              onClick={handleCancelImage}
              className="absolute top-2 right-2 p-1 bg-red-500 text-white rounded-full hover:bg-red-600 transition"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
          <div className="flex gap-2">
            <button
              onClick={handleSendImage}
              disabled={disabled}
              className="flex-1 py-2 px-4 bg-indigo-600 hover:bg-indigo-700 text-white rounded-full disabled:opacity-50 disabled:cursor-not-allowed transition"
            >
              Отправить
            </button>
            <button
              onClick={handleCancelImage}
              className="py-2 px-4 bg-gray-300 hover:bg-gray-400 text-gray-800 rounded-full transition"
            >
              Отмена
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex items-center gap-2 px-4 py-3 border-t border-gray-200 bg-white">
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleImageSelect}
      />
      
      <button
        type="button"
        onClick={() => fileInputRef.current?.click()}
        disabled={disabled}
        className="p-2 text-gray-600 hover:text-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed transition"
        title="Отправить изображение"
      >
        <ImageIcon className="w-6 h-6" />
      </button>
      
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
