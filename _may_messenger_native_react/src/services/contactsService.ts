import { Platform, PermissionsAndroid } from 'react-native';
import Contacts, { Contact } from 'react-native-contacts';
import crypto from 'crypto-js';

export interface ContactInfo {
  displayName: string;
  phoneNumbers: string[];
}

export interface RegisteredContact {
  userId: string;
  displayName: string;
  phoneNumber: string;
}

export const contactsService = {
  /**
   * Request permission to access contacts
   */
  async requestPermission(): Promise<boolean> {
    try {
      if (Platform.OS === 'android') {
        const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.READ_CONTACTS,
          {
            title: 'Доступ к контактам',
            message: 'Приложению нужен доступ к вашим контактам для поиска друзей',
            buttonPositive: 'OK',
            buttonNegative: 'Отмена',
          }
        );
        return granted === PermissionsAndroid.RESULTS.GRANTED;
      } else {
        // iOS
        const permission = await Contacts.checkPermission();
        if (permission === 'undefined' || permission === 'denied') {
          const requestResult = await Contacts.requestPermission();
          return requestResult === 'authorized';
        }
        return permission === 'authorized';
      }
    } catch (error) {
      console.error('Failed to request contacts permission:', error);
      return false;
    }
  },

  /**
   * Get all contacts from phone
   */
  async getAllContacts(): Promise<ContactInfo[]> {
    try {
      const contacts = await Contacts.getAll();
      
      return contacts.map((contact: Contact) => ({
        displayName: contact.displayName || contact.givenName || 'Без имени',
        phoneNumbers: contact.phoneNumbers.map(p => this.normalizePhoneNumber(p.number)),
      }));
    } catch (error) {
      console.error('Failed to get contacts:', error);
      return [];
    }
  },

  /**
   * Normalize phone number (remove spaces, dashes, etc.)
   */
  normalizePhoneNumber(phoneNumber: string): string {
    // Remove all non-digit characters except +
    let normalized = phoneNumber.replace(/[^\d+]/g, '');
    
    // If starts with 8, replace with +7 (Russia)
    if (normalized.startsWith('8')) {
      normalized = '+7' + normalized.substring(1);
    }
    
    // If doesn't start with +, add +7 (Russia default)
    if (!normalized.startsWith('+')) {
      normalized = '+7' + normalized;
    }
    
    return normalized;
  },

  /**
   * Create SHA256 hash of phone number
   */
  hashPhoneNumber(phoneNumber: string): string {
    const normalized = this.normalizePhoneNumber(phoneNumber);
    const hash = crypto.SHA256(normalized).toString();
    return hash;
  },

  /**
   * Sync contacts with server
   * Returns mapping of userId -> displayName
   */
  async syncContactsWithServer(
    token: string,
    apiEndpoint: string
  ): Promise<{ [userId: string]: string }> {
    try {
      const hasPermission = await this.requestPermission();
      if (!hasPermission) {
        console.log('Contacts permission denied');
        return {};
      }

      const contacts = await this.getAllContacts();
      
      // Create hashes of all phone numbers
      const phoneHashes = new Set<string>();
      const hashToName: { [hash: string]: string } = {};
      
      contacts.forEach(contact => {
        contact.phoneNumbers.forEach(phone => {
          const hash = this.hashPhoneNumber(phone);
          phoneHashes.add(hash);
          // Store display name for this hash
          if (!hashToName[hash]) {
            hashToName[hash] = contact.displayName;
          }
        });
      });

      // Send hashes to server
      const response = await fetch(apiEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          phoneHashes: Array.from(phoneHashes),
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to sync contacts with server');
      }

      const registeredContacts: RegisteredContact[] = await response.json();
      
      // Build mapping: userId -> displayName
      const mapping: { [userId: string]: string } = {};
      registeredContacts.forEach(contact => {
        const hash = this.hashPhoneNumber(contact.phoneNumber);
        const displayName = hashToName[hash] || contact.displayName;
        mapping[contact.userId] = displayName;
      });

      console.log(`Synced ${Object.keys(mapping).length} registered contacts`);
      return mapping;
    } catch (error) {
      console.error('Failed to sync contacts:', error);
      return {};
    }
  },

  /**
   * Build contacts mapping from registered users
   */
  buildContactsMapping(registeredUsers: RegisteredContact[]): { [userId: string]: string } {
    const mapping: { [userId: string]: string } = {};
    registeredUsers.forEach(user => {
      mapping[user.userId] = user.displayName;
    });
    return mapping;
  },
};

