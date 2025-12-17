import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../stores/authStore';
import { useSettingsStore } from '../stores/settingsStore';
import { ProfileCard } from '../components/settings/ProfileCard';
import { InviteQRDialog } from '../components/settings/InviteQRDialog';
import { ArrowLeft, QrCode, Gift, Copy, LogOut, Loader2 } from 'lucide-react';

export const SettingsPage = () => {
  const navigate = useNavigate();
  const { user, logout } = useAuthStore();
  const { inviteLinks, isLoading, isCreating, loadInviteLinks, createInviteLink, validInviteLinks } = useSettingsStore();
  const [showQRDialog, setShowQRDialog] = useState(false);
  const [selectedInvite, setSelectedInvite] = useState<{ code: string; link: string } | null>(null);

  useEffect(() => {
    loadInviteLinks();
  }, []);

  const handleCreateInvite = async () => {
    const newInvite = await createInviteLink();
    if (newInvite) {
      setSelectedInvite({ code: newInvite.code, link: newInvite.inviteLink });
      setShowQRDialog(true);
    }
  };

  const handleShowInvite = (code: string, link: string) => {
    setSelectedInvite({ code, link });
    setShowQRDialog(true);
  };

  const handleCopyCode = (code: string) => {
    navigator.clipboard.writeText(code);
  };

  const handleLogout = async () => {
    if (confirm('Вы уверены, что хотите выйти?')) {
      await logout();
      navigate('/login');
    }
  };

  const getInviteDisplayText = (invite: any) => {
    if (invite.isUsed) {
      return `Использован ${new Date(invite.usedAt).toLocaleDateString()}`;
    }
    if (invite.expiresAt) {
      const expiresDate = new Date(invite.expiresAt);
      const now = new Date();
      if (expiresDate < now) {
        return 'Истёк';
      }
      return `Действителен до ${expiresDate.toLocaleDateString()}`;
    }
    return 'Активен';
  };

  const isInviteValid = (invite: any) => {
    if (invite.isUsed) return false;
    if (invite.expiresAt && new Date(invite.expiresAt) < new Date()) return false;
    return true;
  };

  if (!user) return null;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-4xl mx-auto px-4 py-4 flex items-center gap-3">
          <button
            onClick={() => navigate('/')}
            className="p-2 rounded-lg hover:bg-gray-100 transition"
          >
            <ArrowLeft className="w-6 h-6" />
          </button>
          <h1 className="text-2xl font-bold text-gray-900">Настройки</h1>
        </div>
      </header>

      <div className="max-w-4xl mx-auto px-4 py-6 space-y-6">
        {/* Profile Card */}
        <ProfileCard user={user} />

        {/* Invite Section */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <QrCode className="w-6 h-6 text-indigo-600" />
              <div>
                <h3 className="text-lg font-semibold text-gray-900">
                  Пригласить друга
                </h3>
                <p className="text-sm text-gray-600">
                  Создайте QR код для приглашения
                </p>
              </div>
            </div>
            <button
              onClick={handleCreateInvite}
              disabled={isCreating}
              className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            >
              {isCreating ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Создание...
                </>
              ) : (
                'Создать код'
              )}
            </button>
          </div>
        </div>

        {/* My Invite Codes */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <div className="flex items-center gap-3 mb-4">
            <Gift className="w-6 h-6 text-indigo-600" />
            <div>
              <h3 className="text-lg font-semibold text-gray-900">
                Мои коды приглашения
              </h3>
              <p className="text-sm text-gray-600">
                Активных: {validInviteLinks.length}
              </p>
            </div>
          </div>

          {isLoading ? (
            <div className="flex justify-center py-8">
              <Loader2 className="w-8 h-8 animate-spin text-indigo-600" />
            </div>
          ) : inviteLinks.length === 0 ? (
            <p className="text-gray-500 text-center py-8">
              У вас пока нет созданных кодов
            </p>
          ) : (
            <div className="space-y-3">
              {inviteLinks.map((invite) => {
                const valid = isInviteValid(invite);
                return (
                  <div
                    key={invite.id}
                    className={`flex items-center justify-between p-4 rounded-lg border ${
                      valid ? 'border-green-200 bg-green-50' : 'border-gray-200 bg-gray-50'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className={`w-3 h-3 rounded-full ${
                          valid ? 'bg-green-500' : 'bg-gray-400'
                        }`}
                      />
                      <div>
                        <p className="font-mono font-bold text-gray-900">
                          {invite.code}
                        </p>
                        <p className="text-sm text-gray-600">
                          {getInviteDisplayText(invite)}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => handleCopyCode(invite.code)}
                        className="p-2 rounded-lg hover:bg-gray-200 transition"
                        title="Копировать код"
                      >
                        <Copy className="w-5 h-5 text-gray-600" />
                      </button>
                      {valid && invite.inviteLink && (
                        <button
                          onClick={() => handleShowInvite(invite.code, invite.inviteLink!)}
                          className="px-3 py-1 text-sm bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition"
                        >
                          QR код
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Logout */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <button
            onClick={handleLogout}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 text-red-600 hover:bg-red-50 rounded-lg transition font-medium"
          >
            <LogOut className="w-5 h-5" />
            Выйти
          </button>
        </div>
      </div>

      {/* QR Dialog */}
      {showQRDialog && selectedInvite && (
        <InviteQRDialog
          inviteCode={selectedInvite.code}
          inviteLink={selectedInvite.link}
          onClose={() => setShowQRDialog(false)}
        />
      )}
    </div>
  );
};

