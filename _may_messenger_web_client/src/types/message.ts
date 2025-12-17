export interface InviteLink {
  id: string;
  code: string;
  createdById: string;
  createdAt: string;
  expiresAt?: string;
  isUsed: boolean;
  usedAt?: string;
  usedById?: string;
  inviteLink?: string;
}

export interface InviteLinkResponse {
  code: string;
  inviteLink: string;
}
