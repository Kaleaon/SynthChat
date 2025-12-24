"""
Google Drive storage manager for agent memories and documents.
"""

import os
import json
from typing import Optional, Dict, Any, List
from datetime import datetime
import pickle
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload, MediaInMemoryUpload
from googleapiclient.errors import HttpError


# If modifying these scopes, delete the file token.json.
SCOPES = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/spreadsheets'
]


class GoogleDriveStorage:
    """Manages Google Drive storage for agent memories and documents."""
    
    def __init__(self, credentials_path: str = "credentials.json", 
                 token_path: str = "token.json",
                 folder_id: Optional[str] = None):
        """
        Initialize Google Drive storage.
        
        Args:
            credentials_path: Path to Google API credentials file
            token_path: Path to store/load user token
            folder_id: Optional parent folder ID for all agent files
        """
        self.credentials_path = credentials_path
        self.token_path = token_path
        self.folder_id = folder_id
        self.creds = None
        self.drive_service = None
        self.sheets_service = None
        self._authenticate()
    
    def _authenticate(self):
        """Authenticate with Google Drive API."""
        # The file token.json stores the user's access and refresh tokens
        if os.path.exists(self.token_path):
            self.creds = Credentials.from_authorized_user_file(self.token_path, SCOPES)
        
        # If there are no (valid) credentials available, let the user log in.
        if not self.creds or not self.creds.valid:
            if self.creds and self.creds.expired and self.creds.refresh_token:
                self.creds.refresh(Request())
            else:
                if not os.path.exists(self.credentials_path):
                    raise FileNotFoundError(
                        f"Credentials file not found at {self.credentials_path}. "
                        "Please download it from Google Cloud Console."
                    )
                flow = InstalledAppFlow.from_client_secrets_file(
                    self.credentials_path, SCOPES)
                self.creds = flow.run_local_server(port=0)
            
            # Save the credentials for the next run
            with open(self.token_path, 'w') as token:
                token.write(self.creds.to_json())
        
        self.drive_service = build('drive', 'v3', credentials=self.creds)
        self.sheets_service = build('sheets', 'v4', credentials=self.creds)
    
    def create_agent_folder(self, agent_name: str) -> str:
        """
        Create a dedicated folder for an agent.
        
        Args:
            agent_name: Name of the agent
            
        Returns:
            Folder ID
        """
        file_metadata = {
            'name': f'{agent_name}_Memory',
            'mimeType': 'application/vnd.google-apps.folder'
        }
        
        if self.folder_id:
            file_metadata['parents'] = [self.folder_id]
        
        try:
            folder = self.drive_service.files().create(
                body=file_metadata,
                fields='id'
            ).execute()
            return folder.get('id')
        except HttpError as error:
            print(f"An error occurred creating folder: {error}")
            raise
    
    def create_agent_document(self, agent_name: str, folder_id: str, 
                             doc_type: str = "memory") -> str:
        """
        Create a Google Doc for agent memory or thoughts.
        
        Args:
            agent_name: Name of the agent
            folder_id: Parent folder ID
            doc_type: Type of document (memory, thoughts, character)
            
        Returns:
            Document ID
        """
        file_metadata = {
            'name': f'{agent_name}_{doc_type}',
            'mimeType': 'application/vnd.google-apps.document',
            'parents': [folder_id]
        }
        
        try:
            doc = self.drive_service.files().create(
                body=file_metadata,
                fields='id'
            ).execute()
            return doc.get('id')
        except HttpError as error:
            print(f"An error occurred creating document: {error}")
            raise
    
    def create_agent_spreadsheet(self, agent_name: str, folder_id: str) -> str:
        """
        Create a Google Sheet for agent character development tracking.
        
        Args:
            agent_name: Name of the agent
            folder_id: Parent folder ID
            
        Returns:
            Spreadsheet ID
        """
        file_metadata = {
            'name': f'{agent_name}_CharacterDevelopment',
            'mimeType': 'application/vnd.google-apps.spreadsheet',
            'parents': [folder_id]
        }
        
        try:
            sheet = self.drive_service.files().create(
                body=file_metadata,
                fields='id'
            ).execute()
            
            sheet_id = sheet.get('id')
            
            # Initialize the spreadsheet with headers
            self._initialize_character_sheet(sheet_id, agent_name)
            
            return sheet_id
        except HttpError as error:
            print(f"An error occurred creating spreadsheet: {error}")
            raise
    
    def _initialize_character_sheet(self, sheet_id: str, agent_name: str):
        """Initialize the character development spreadsheet with headers."""
        try:
            # Create sheets for different aspects
            requests = [
                {
                    'updateSheetProperties': {
                        'properties': {
                            'sheetId': 0,
                            'title': 'Interactions'
                        },
                        'fields': 'title'
                    }
                },
                {
                    'addSheet': {
                        'properties': {
                            'title': 'Character Traits'
                        }
                    }
                },
                {
                    'addSheet': {
                        'properties': {
                            'title': 'Memory Snapshots'
                        }
                    }
                }
            ]
            
            self.sheets_service.spreadsheets().batchUpdate(
                spreadsheetId=sheet_id,
                body={'requests': requests}
            ).execute()
            
            # Add headers to Interactions sheet
            values = [
                ['Timestamp', 'User', 'Agent Response', 'Thought Pattern', 'Emotion', 'Context']
            ]
            
            self.sheets_service.spreadsheets().values().update(
                spreadsheetId=sheet_id,
                range='Interactions!A1:F1',
                valueInputOption='RAW',
                body={'values': values}
            ).execute()
            
            # Add headers to Character Traits sheet
            trait_values = [
                ['Trait', 'Value', 'Last Updated', 'Notes']
            ]
            
            self.sheets_service.spreadsheets().values().update(
                spreadsheetId=sheet_id,
                range='Character Traits!A1:D1',
                valueInputOption='RAW',
                body={'values': trait_values}
            ).execute()
            
        except HttpError as error:
            print(f"An error occurred initializing sheet: {error}")
    
    def append_interaction(self, sheet_id: str, interaction_data: Dict[str, Any]):
        """
        Append an interaction to the agent's spreadsheet.
        
        Args:
            sheet_id: Spreadsheet ID
            interaction_data: Dictionary containing interaction details
        """
        timestamp = interaction_data.get('timestamp', datetime.now().isoformat())
        user_input = interaction_data.get('user_input', '')
        agent_response = interaction_data.get('agent_response', '')
        thought_pattern = interaction_data.get('thought_pattern', '')
        emotion = interaction_data.get('emotion', '')
        context = interaction_data.get('context', '')
        
        values = [
            [timestamp, user_input, agent_response, thought_pattern, emotion, context]
        ]
        
        try:
            self.sheets_service.spreadsheets().values().append(
                spreadsheetId=sheet_id,
                range='Interactions!A:F',
                valueInputOption='RAW',
                insertDataOption='INSERT_ROWS',
                body={'values': values}
            ).execute()
        except HttpError as error:
            print(f"An error occurred appending interaction: {error}")
    
    def update_character_trait(self, sheet_id: str, trait: str, 
                               value: str, notes: str = ""):
        """
        Update or add a character trait.
        
        Args:
            sheet_id: Spreadsheet ID
            trait: Trait name
            value: Trait value
            notes: Optional notes
        """
        timestamp = datetime.now().isoformat()
        
        try:
            # First, try to find if trait exists
            result = self.sheets_service.spreadsheets().values().get(
                spreadsheetId=sheet_id,
                range='Character Traits!A:A'
            ).execute()
            
            values = result.get('values', [])
            row_index = None
            
            for i, row in enumerate(values):
                if row and row[0] == trait:
                    row_index = i + 1
                    break
            
            if row_index:
                # Update existing trait
                update_range = f'Character Traits!B{row_index}:D{row_index}'
                update_values = [[value, timestamp, notes]]
            else:
                # Add new trait
                update_range = 'Character Traits!A:D'
                update_values = [[trait, value, timestamp, notes]]
            
            self.sheets_service.spreadsheets().values().append(
                spreadsheetId=sheet_id,
                range=update_range,
                valueInputOption='RAW',
                insertDataOption='INSERT_ROWS' if not row_index else 'OVERWRITE',
                body={'values': update_values}
            ).execute()
            
        except HttpError as error:
            print(f"An error occurred updating trait: {error}")
    
    def append_to_document(self, doc_id: str, content: str):
        """
        Append content to a Google Doc.
        
        Note: This requires the Google Docs API which has limited write capabilities.
        For now, we'll use Drive API to manage the file.
        
        Args:
            doc_id: Document ID
            content: Content to append
        """
        # Note: Google Docs API has limited direct content manipulation
        # In a production system, you'd use the Docs API to insert text
        # For this implementation, we'll store a reference that content should be added
        print(f"Content to append to doc {doc_id}: {content[:100]}...")
    
    def get_or_create_agent_files(self, agent_name: str) -> Dict[str, str]:
        """
        Get existing or create new Google Drive files for an agent.
        
        Args:
            agent_name: Name of the agent
            
        Returns:
            Dictionary with folder_id, memory_doc_id, thoughts_doc_id, sheet_id
        """
        # Search for existing folder
        query = f"name='{agent_name}_Memory' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        
        try:
            results = self.drive_service.files().list(
                q=query,
                spaces='drive',
                fields='files(id, name)'
            ).execute()
            
            files = results.get('files', [])
            
            if files:
                # Folder exists, get existing files
                folder_id = files[0]['id']
                
                # Search for existing documents in this folder
                doc_query = f"'{folder_id}' in parents and trashed=false"
                doc_results = self.drive_service.files().list(
                    q=doc_query,
                    spaces='drive',
                    fields='files(id, name, mimeType)'
                ).execute()
                
                existing_files = doc_results.get('files', [])
                
                memory_doc_id = None
                thoughts_doc_id = None
                sheet_id = None
                
                for file in existing_files:
                    if file['name'] == f'{agent_name}_memory':
                        memory_doc_id = file['id']
                    elif file['name'] == f'{agent_name}_thoughts':
                        thoughts_doc_id = file['id']
                    elif file['name'] == f'{agent_name}_CharacterDevelopment':
                        sheet_id = file['id']
                
                # Create missing files
                if not memory_doc_id:
                    memory_doc_id = self.create_agent_document(agent_name, folder_id, "memory")
                if not thoughts_doc_id:
                    thoughts_doc_id = self.create_agent_document(agent_name, folder_id, "thoughts")
                if not sheet_id:
                    sheet_id = self.create_agent_spreadsheet(agent_name, folder_id)
                
            else:
                # Create new folder and files
                folder_id = self.create_agent_folder(agent_name)
                memory_doc_id = self.create_agent_document(agent_name, folder_id, "memory")
                thoughts_doc_id = self.create_agent_document(agent_name, folder_id, "thoughts")
                sheet_id = self.create_agent_spreadsheet(agent_name, folder_id)
            
            return {
                'folder_id': folder_id,
                'memory_doc_id': memory_doc_id,
                'thoughts_doc_id': thoughts_doc_id,
                'sheet_id': sheet_id
            }
            
        except HttpError as error:
            print(f"An error occurred: {error}")
            raise
