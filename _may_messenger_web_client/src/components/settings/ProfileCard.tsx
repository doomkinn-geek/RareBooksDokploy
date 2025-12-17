import { UserProfile } from '../../types/auth';
import { User } from 'lucide-react';

interface ProfileCardProps {
  user: UserProfile;
}

export const ProfileCard = ({ user }: ProfileCardProps) => {
  return (
    <div className="bg-white rounded-lg shadow-sm p-6">
      <div className="flex flex-col items-center">
        {/* Avatar */}
        <div className="w-24 h-24 bg-indigo-600 rounded-full flex items-center justify-center text-white text-3xl font-semibold mb-4">
          {user.avatar ? (
            <img 
              src={user.avatar} 
              alt={user.displayName} 
              className="w-full h-full rounded-full object-cover"
            />
          ) : (
            <User className="w-12 h-12" />
          )}
        </div>
        
        {/* Name */}
        <h2 className="text-2xl font-bold text-gray-900 mb-2">
          {user.displayName}
        </h2>
        
        {/* Phone */}
        <p className="text-gray-600 mb-3">
          {user.phoneNumber}
        </p>
        
        {/* Admin Badge */}
        {user.isAdmin && (
          <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-indigo-100 text-indigo-800">
            Администратор
          </span>
        )}
      </div>
    </div>
  );
};

