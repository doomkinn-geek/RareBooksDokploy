import { useState, useEffect, useRef } from 'react';
import { Play, Pause } from 'lucide-react';
import { audioPlayer } from '../../services/audioPlayer';
import { formatDuration } from '../../utils/formatters';
import { API_URL } from '../../utils/constants';

interface AudioPlayerProps {
  filePath: string;
  isOwnMessage: boolean;
  onPlay?: () => void;
}

export const AudioPlayer = ({ filePath, isOwnMessage, onPlay }: AudioPlayerProps) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const audioUrl = `${API_URL}${filePath}`;
  const cleanupRef = useRef<(() => void)[]>([]);
  const hasTriggeredPlay = useRef(false);

  useEffect(() => {
    // Set up audio event listeners
    const audio = new Audio(audioUrl);
    
    const onLoadedMetadata = () => {
      setDuration(audio.duration);
    };
    
    audio.addEventListener('loadedmetadata', onLoadedMetadata);
    audio.load();
    
    return () => {
      audio.removeEventListener('loadedmetadata', onLoadedMetadata);
      cleanupRef.current.forEach((cleanup) => cleanup());
    };
  }, [audioUrl]);

  const handlePlayPause = async () => {
    try {
      if (audioPlayer.isPlaying(audioUrl)) {
        audioPlayer.pause();
        setIsPlaying(false);
      } else {
        await audioPlayer.play(audioUrl);
        setIsPlaying(true);
        
        // Trigger onPlay callback when first starting playback
        if (!hasTriggeredPlay.current && onPlay) {
          hasTriggeredPlay.current = true;
          onPlay();
        }
        
        // Set up time update listener
        const cleanup1 = audioPlayer.onTimeUpdate((time) => {
          setCurrentTime(time);
        });
        
        const cleanup2 = audioPlayer.onEnded(() => {
          setIsPlaying(false);
          setCurrentTime(0);
        });
        
        cleanupRef.current = [cleanup1, cleanup2];
      }
    } catch (error) {
      console.error('Failed to play audio', error);
    }
  };

  const progress = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <div className="flex items-center gap-2 min-w-[200px]">
      <button
        onClick={handlePlayPause}
        className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
          isOwnMessage
            ? 'bg-white/20 hover:bg-white/30'
            : 'bg-indigo-100 hover:bg-indigo-200'
        }`}
      >
        {isPlaying ? (
          <Pause className={`w-5 h-5 ${isOwnMessage ? 'text-white' : 'text-indigo-600'}`} />
        ) : (
          <Play className={`w-5 h-5 ${isOwnMessage ? 'text-white' : 'text-indigo-600'}`} />
        )}
      </button>
      
      <div className="flex-1">
        <div className="relative h-1 bg-gray-300 rounded-full overflow-hidden">
          <div
            className={`absolute top-0 left-0 h-full ${
              isOwnMessage ? 'bg-white' : 'bg-indigo-600'
            }`}
            style={{ width: `${progress}%` }}
          />
        </div>
        
        <div className={`text-xs mt-1 ${isOwnMessage ? 'text-white/70' : 'text-gray-500'}`}>
          {formatDuration(isPlaying ? currentTime : duration)}
        </div>
      </div>
    </div>
  );
};
