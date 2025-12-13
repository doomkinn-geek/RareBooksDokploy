export class AudioPlayerService {
  private audio: HTMLAudioElement | null = null;
  private currentUrl: string | null = null;

  async play(url: string): Promise<void> {
    // If already playing this URL, just resume
    if (this.audio && this.currentUrl === url) {
      if (this.audio.paused) {
        await this.audio.play();
      }
      return;
    }

    // Stop current audio if playing
    this.stop();

    // Create new audio element
    this.audio = new Audio(url);
    this.currentUrl = url;

    try {
      await this.audio.play();
      console.log('[AudioPlayer] Playing', url);
    } catch (error) {
      console.error('[AudioPlayer] Failed to play', error);
      throw new Error('Не удалось воспроизвести аудио');
    }
  }

  pause(): void {
    if (this.audio && !this.audio.paused) {
      this.audio.pause();
      console.log('[AudioPlayer] Paused');
    }
  }

  stop(): void {
    if (this.audio) {
      this.audio.pause();
      this.audio.currentTime = 0;
      this.audio = null;
      this.currentUrl = null;
      console.log('[AudioPlayer] Stopped');
    }
  }

  seek(time: number): void {
    if (this.audio) {
      this.audio.currentTime = time;
    }
  }

  setVolume(volume: number): void {
    if (this.audio) {
      this.audio.volume = Math.max(0, Math.min(1, volume));
    }
  }

  getCurrentTime(): number {
    return this.audio?.currentTime || 0;
  }

  getDuration(): number {
    return this.audio?.duration || 0;
  }

  isPlaying(url?: string): boolean {
    if (url) {
      return this.audio !== null && this.currentUrl === url && !this.audio.paused;
    }
    return this.audio !== null && !this.audio.paused;
  }

  onTimeUpdate(callback: (currentTime: number) => void): () => void {
    const handler = () => callback(this.getCurrentTime());
    this.audio?.addEventListener('timeupdate', handler);
    
    return () => {
      this.audio?.removeEventListener('timeupdate', handler);
    };
  }

  onEnded(callback: () => void): () => void {
    this.audio?.addEventListener('ended', callback);
    
    return () => {
      this.audio?.removeEventListener('ended', callback);
    };
  }

  onLoadedMetadata(callback: (duration: number) => void): () => void {
    const handler = () => callback(this.getDuration());
    this.audio?.addEventListener('loadedmetadata', handler);
    
    return () => {
      this.audio?.removeEventListener('loadedmetadata', handler);
    };
  }
}

export const audioPlayer = new AudioPlayerService();
