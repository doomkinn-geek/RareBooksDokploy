# Firebase Google Services Configuration

## Where to place google-services.json

After downloading `google-services.json` from Firebase Console, place it here:

```
_may_messenger_mobile_app/android/app/google-services.json
```

## How to get google-services.json

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project (MayMessenger)
3. Go to **Project Settings** (gear icon)
4. Scroll down to **Your apps** section
5. Select your Android app (or add a new Android app if needed)
   - Package name: `com.maymessenger.mobile_app`
6. Click **Download google-services.json**
7. Copy the downloaded file to `_may_messenger_mobile_app/android/app/google-services.json`

## Important Notes

- **DO NOT** commit this file to git (it's already in `.gitignore`)
- This file contains sensitive Firebase configuration
- Keep it in `_may_messenger_secrets` for backup
- Each developer needs their own copy for local development

## Verification

After placing the file, verify it contains:

```json
{
  "project_info": {
    "project_number": "...",
    "project_id": "your-project-id",
    ...
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "...",
        "android_client_info": {
          "package_name": "com.maymessenger.mobile_app"
        }
      },
      ...
    }
  ]
}
```

Package name MUST match `com.maymessenger.mobile_app`.
