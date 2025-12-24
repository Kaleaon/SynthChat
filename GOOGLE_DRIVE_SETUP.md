# Google Drive Setup Guide

This guide walks you through setting up Google Drive integration for SynthChat.

## Prerequisites

- A Google account
- Access to [Google Cloud Console](https://console.cloud.google.com/)

## Step-by-Step Setup

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click on the project dropdown at the top of the page
3. Click "New Project"
4. Enter a project name (e.g., "SynthChat")
5. Click "Create"

### 2. Enable Required APIs

1. In your new project, go to "APIs & Services" > "Library"
2. Search for "Google Drive API" and click on it
3. Click "Enable"
4. Go back to the Library
5. Search for "Google Sheets API" and click on it
6. Click "Enable"

### 3. Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. If prompted, configure the OAuth consent screen:
   - Choose "External" user type
   - Fill in the required fields:
     - App name: "SynthChat"
     - User support email: your email
     - Developer contact email: your email
   - Click "Save and Continue"
   - Skip the "Scopes" section (click "Save and Continue")
   - Add your email as a test user
   - Click "Save and Continue"
4. Back on the "Create OAuth client ID" page:
   - Application type: "Desktop app"
   - Name: "SynthChat Desktop"
   - Click "Create"
5. Download the credentials file (JSON)
6. Rename it to `credentials.json` and place it in the SynthChat root directory

### 4. First Run - Authentication

When you run SynthChat for the first time with Google Drive credentials:

1. The application will open a browser window
2. Sign in with your Google account
3. Review the permissions requested:
   - See and download files created with this app
   - See, edit, create, and delete your spreadsheets
4. Click "Continue" or "Allow"
5. You may see a warning that the app isn't verified - click "Advanced" > "Go to SynthChat (unsafe)"
6. Grant the permissions

A `token.json` file will be created in your project directory. This stores your authentication token for future use.

### 5. Optional: Create a Parent Folder

To keep all agent memories organized:

1. Go to [Google Drive](https://drive.google.com/)
2. Create a new folder (e.g., "SynthChat Agents")
3. Right-click on the folder and select "Get link" > "Copy link"
4. The link will look like: `https://drive.google.com/drive/folders/FOLDER_ID_HERE`
5. Copy the `FOLDER_ID_HERE` part
6. Add it to your `.env` file:
   ```
   AGENT_MEMORY_FOLDER_ID=FOLDER_ID_HERE
   ```

Now all agent folders will be created inside this parent folder.

## What Gets Created in Google Drive

For each agent, SynthChat creates:

### Folder Structure
```
SynthChat Agents/  (optional parent folder)
├── Alice_Memory/
│   ├── Alice_memory (Google Doc)
│   ├── Alice_thoughts (Google Doc)
│   └── Alice_CharacterDevelopment (Google Sheet)
├── Bob_Memory/
│   ├── Bob_memory (Google Doc)
│   ├── Bob_thoughts (Google Doc)
│   └── Bob_CharacterDevelopment (Google Sheet)
└── Carol_Memory/
    ├── Carol_memory (Google Doc)
    ├── Carol_thoughts (Google Doc)
    └── Carol_CharacterDevelopment (Google Sheet)
```

### Character Development Spreadsheet

Each agent's spreadsheet contains three sheets:

1. **Interactions**: All conversations with timestamps
   - Timestamp
   - User Input
   - Agent Response
   - Thought Pattern
   - Emotion
   - Context

2. **Character Traits**: Tracked characteristics
   - Trait Name
   - Value
   - Last Updated
   - Notes

3. **Memory Snapshots**: Periodic state saves (for future use)

## Troubleshooting

### "Credentials file not found"
- Make sure `credentials.json` is in the project root directory
- Check that the filename is exactly `credentials.json`

### "Invalid credentials"
- Delete `token.json` and run the application again
- Follow the authentication flow in your browser

### "Access denied" or permission errors
- Make sure you granted all requested permissions during OAuth flow
- Check that both Google Drive API and Google Sheets API are enabled in your Google Cloud project

### "The app is blocked"
- This happens if you haven't added your email as a test user
- Go to Google Cloud Console > APIs & Services > OAuth consent screen
- Add your email under "Test users"

### Rate limits
- Google Drive API has usage quotas
- For normal use, you shouldn't hit these limits
- If you do, wait a few minutes and try again

## Security Best Practices

1. **Never commit credentials**:
   - `credentials.json` and `token.json` are in `.gitignore`
   - Never share these files publicly

2. **Revoke access** if needed:
   - Go to [Google Account Security](https://myaccount.google.com/permissions)
   - Find "SynthChat" and click "Remove Access"

3. **Use test users only**:
   - Keep your OAuth consent screen in "Testing" mode
   - Only add trusted users as test users

## Advanced Configuration

### Using a Service Account (for production)

For production deployments, consider using a Service Account instead of OAuth:

1. In Google Cloud Console, go to "IAM & Admin" > "Service Accounts"
2. Create a new service account
3. Download the JSON key file
4. Share your Google Drive folder with the service account email
5. Update the code to use service account credentials

### API Quotas

Default quotas (per day):
- Google Drive API: 1,000,000,000 queries
- Google Sheets API: 500 read requests per 100 seconds per user

For most use cases, these are more than sufficient.

## Need Help?

If you encounter issues not covered here, please:
1. Check the [Google Drive API documentation](https://developers.google.com/drive/api/guides/about-sdk)
2. Check the [Google Sheets API documentation](https://developers.google.com/sheets/api/guides/concepts)
3. Open an issue on the GitHub repository
