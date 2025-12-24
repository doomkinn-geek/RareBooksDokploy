import { useState, useRef, useEffect } from 'react';
import { Smile } from 'lucide-react';

interface EmojiPickerProps {
  onEmojiSelect: (emoji: string) => void;
}

const EMOJI_CATEGORIES = {
  'Часто используемые': ['😀', '😂', '😊', '😍', '🥰', '😘', '😭', '😅', '😎', '🤔', '😏', '😡', '😢', '😱', '🤯', '🥳'],
  'Жесты': ['👍', '👎', '👌', '✌️', '🤞', '🤙', '👊', '✊', '👏', '🙌', '🤝', '🙏', '💪', '🤗', '🤦', '🤷'],
  'Сердечки': ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘'],
  'Объекты': ['🔥', '✨', '💫', '⭐', '🌟', '💯', '💥', '💢', '🎉', '🎊', '🎁', '🎈', '🏆', '🎯', '🎵', '🎶'],
  'Еда': ['☕', '🍕', '🍔', '🍟', '🌭', '🥪', '🍿', '🍩', '🍪', '🎂', '🍰', '🍫', '🍬', '🍭', '🍺', '🍷'],
  'Природа': ['🌞', '🌝', '🌙', '⭐', '🌈', '☁️', '⛅', '🌧️', '❄️', '💨', '🌊', '🌸', '🌺', '🌻', '🍀', '🌴'],
  'Животные': ['🐱', '🐶', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔'],
};

export const EmojiPicker = ({ onEmojiSelect }: EmojiPickerProps) => {
  const [isOpen, setIsOpen] = useState(false);
  const [activeCategory, setActiveCategory] = useState<string>('Часто используемые');
  const pickerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (pickerRef.current && !pickerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleEmojiClick = (emoji: string) => {
    onEmojiSelect(emoji);
    setIsOpen(false);
  };

  return (
    <div ref={pickerRef} className="relative">
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className="p-2 rounded-full hover:bg-gray-100 transition-colors text-gray-500 hover:text-gray-700"
        title="Добавить эмодзи"
      >
        <Smile className="w-5 h-5" />
      </button>

      {isOpen && (
        <div className="absolute bottom-full left-0 mb-2 w-80 bg-white rounded-lg shadow-xl border border-gray-200 z-50">
          {/* Category tabs */}
          <div className="flex overflow-x-auto border-b border-gray-200 p-1 gap-1">
            {Object.keys(EMOJI_CATEGORIES).map((category) => (
              <button
                key={category}
                onClick={() => setActiveCategory(category)}
                className={`px-2 py-1 text-xs rounded whitespace-nowrap transition-colors ${
                  activeCategory === category
                    ? 'bg-indigo-100 text-indigo-700'
                    : 'text-gray-600 hover:bg-gray-100'
                }`}
              >
                {category}
              </button>
            ))}
          </div>

          {/* Emoji grid */}
          <div className="p-2 max-h-48 overflow-y-auto">
            <div className="grid grid-cols-8 gap-1">
              {EMOJI_CATEGORIES[activeCategory as keyof typeof EMOJI_CATEGORIES].map((emoji, index) => (
                <button
                  key={`${emoji}-${index}`}
                  onClick={() => handleEmojiClick(emoji)}
                  className="w-8 h-8 flex items-center justify-center text-xl hover:bg-gray-100 rounded transition-colors"
                >
                  {emoji}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

