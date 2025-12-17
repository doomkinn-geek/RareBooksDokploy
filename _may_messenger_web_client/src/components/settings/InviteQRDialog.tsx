import { QRCodeSVG } from 'qrcode.react';
import { X, Copy, Share2 } from 'lucide-react';
import { useState } from 'react';

interface InviteQRDialogProps {
  inviteCode: string;
  inviteLink: string;
  onClose: () => void;
}

export const InviteQRDialog = ({ inviteCode, inviteLink, onClose }: InviteQRDialogProps) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(inviteCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleShare = () => {
    const shareText = `Присоединяйся к May Messenger!\n\nИспользуй код приглашения: ${inviteCode}\nИли перейди по ссылке: ${inviteLink}\n\nКод действителен 7 дней.`;
    
    if (navigator.share) {
      navigator.share({
        title: 'Приглашение в May Messenger',
        text: shareText,
      }).catch(err => console.log('Share failed:', err));
    } else {
      navigator.clipboard.writeText(shareText);
      alert('Текст приглашения скопирован в буфер обмена!');
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6 relative">
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition"
        >
          <X className="w-6 h-6" />
        </button>

        {/* Header */}
        <div className="mb-6">
          <h2 className="text-2xl font-bold text-gray-900 mb-2">
            Пригласить друга
          </h2>
          <p className="text-gray-600">
            Попросите друга отсканировать этот QR код или введите код вручную
          </p>
        </div>

        {/* QR Code */}
        <div className="bg-white p-6 rounded-lg shadow-md mb-6 flex justify-center">
          <QRCodeSVG
            value={inviteLink}
            size={200}
            level="M"
            includeMargin={true}
          />
        </div>

        {/* Invite Code */}
        <div className="bg-gray-100 rounded-lg p-4 mb-6">
          <div className="flex items-center justify-between">
            <span className="text-xl font-mono font-bold text-gray-900">
              {inviteCode}
            </span>
            <button
              onClick={handleCopy}
              className="ml-3 p-2 rounded-lg hover:bg-gray-200 transition"
              title="Копировать код"
            >
              <Copy className="w-5 h-5 text-gray-600" />
            </button>
          </div>
          {copied && (
            <p className="text-sm text-green-600 mt-2">Код скопирован!</p>
          )}
        </div>

        {/* Action Buttons */}
        <div className="flex gap-3">
          <button
            onClick={handleShare}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 border border-indigo-600 text-indigo-600 rounded-lg hover:bg-indigo-50 transition font-medium"
          >
            <Share2 className="w-5 h-5" />
            Поделиться
          </button>
          <button
            onClick={onClose}
            className="flex-1 px-4 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition font-medium"
          >
            Закрыть
          </button>
        </div>

        {/* Info */}
        <p className="text-sm text-gray-500 text-center mt-4">
          Код действителен 7 дней и может быть использован 1 раз
        </p>
      </div>
    </div>
  );
};

