class AudioRecorderService {
  private mediaRecorder: MediaRecorder | null = null;
  private audioChunks: Blob[] = [];
  private stream: MediaStream | null = null;

  async startRecording(): Promise<void> {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      
      // Try to use the best available audio format
      const mimeType = this.getSupportedMimeType();
      
      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType,
        audioBitsPerSecond: 128000,
      });

      this.audioChunks = [];

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data);
        }
      };

      this.mediaRecorder.start();
      console.log('[AudioRecorder] Recording started');
    } catch (error) {
      console.error('[AudioRecorder] Failed to start recording', error);
      throw new Error('Не удалось получить доступ к микрофону');
    }
  }

  async stopRecording(): Promise<Blob> {
    return new Promise((resolve, reject) => {
      if (!this.mediaRecorder) {
        reject(new Error('Запись не начата'));
        return;
      }

      this.mediaRecorder.onstop = () => {
        const mimeType = this.mediaRecorder!.mimeType;
        const audioBlob = new Blob(this.audioChunks, { type: mimeType });
        
        // Stop all tracks
        if (this.stream) {
          this.stream.getTracks().forEach((track) => track.stop());
          this.stream = null;
        }

        this.mediaRecorder = null;
        this.audioChunks = [];
        
        console.log('[AudioRecorder] Recording stopped', audioBlob.size, 'bytes');
        resolve(audioBlob);
      };

      this.mediaRecorder.stop();
    });
  }

  cancelRecording(): void {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop();
    }

    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }

    this.mediaRecorder = null;
    this.audioChunks = [];
    console.log('[AudioRecorder] Recording cancelled');
  }

  isRecording(): boolean {
    return this.mediaRecorder?.state === 'recording';
  }

  private getSupportedMimeType(): string {
    const types = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4',
    ];

    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }

    return '';
  }
}

export const audioRecorder = new AudioRecorderService();
