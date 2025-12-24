/**
 * SynthChat - Chat Interface JavaScript
 */

// State
let currentUser = null;
let characters = [];
let currentCharacter = null;
let conversations = [];
let currentConversation = null;
let messages = [];

// DOM Elements
const elements = {
    sidebar: null,
    characterList: null,
    conversationList: null,
    conversationsSection: null,
    emptyState: null,
    chatContainer: null,
    messagesContainer: null,
    messages: null,
    messageInput: null,
    sendBtn: null,
    currentAvatar: null,
    currentCharacterName: null,
    currentCharacterStatus: null,
    userInfo: null,
    characterModal: null,
    characterForm: null,
    characterInfoModal: null,
};

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
    initElements();
    initEventListeners();
    
    try {
        await loadCurrentUser();
        await loadCharacters();
        handleHashChange();
    } catch (err) {
        console.error('Initialization error:', err);
        window.location.href = '/login';
    }
});

function initElements() {
    elements.sidebar = document.getElementById('sidebar');
    elements.characterList = document.getElementById('character-list');
    elements.conversationList = document.getElementById('conversation-list');
    elements.conversationsSection = document.getElementById('conversations-section');
    elements.emptyState = document.getElementById('empty-state');
    elements.chatContainer = document.getElementById('chat-container');
    elements.messagesContainer = document.getElementById('messages-container');
    elements.messages = document.getElementById('messages');
    elements.messageInput = document.getElementById('message-input');
    elements.sendBtn = document.getElementById('send-btn');
    elements.currentAvatar = document.getElementById('current-avatar');
    elements.currentCharacterName = document.getElementById('current-character-name');
    elements.currentCharacterStatus = document.getElementById('current-character-status');
    elements.userInfo = document.getElementById('user-info');
    elements.characterModal = document.getElementById('character-modal');
    elements.characterForm = document.getElementById('character-form');
    elements.characterInfoModal = document.getElementById('character-info-modal');
}

function initEventListeners() {
    // Sidebar toggle
    document.getElementById('toggle-sidebar')?.addEventListener('click', toggleSidebar);
    
    // Add character buttons
    document.getElementById('add-character-btn')?.addEventListener('click', openCreateCharacterModal);
    document.getElementById('create-first-character')?.addEventListener('click', openCreateCharacterModal);
    
    // New conversation
    document.getElementById('new-conversation-btn')?.addEventListener('click', createNewConversation);
    
    // Character form
    elements.characterForm?.addEventListener('submit', handleCharacterFormSubmit);
    
    // Avatar upload
    document.getElementById('upload-avatar-btn')?.addEventListener('click', () => {
        document.getElementById('avatar-input')?.click();
    });
    
    document.getElementById('avatar-input')?.addEventListener('change', handleAvatarUpload);
    
    // Avatar generation
    document.getElementById('generate-avatar-btn')?.addEventListener('click', handleGenerateAvatar);
    
    // Temperature slider
    document.getElementById('char-temperature')?.addEventListener('input', (e) => {
        document.getElementById('temp-value').textContent = e.target.value;
    });
    
    // Delete character
    document.getElementById('delete-character-btn')?.addEventListener('click', handleDeleteCharacter);
    
    // Edit character
    document.getElementById('edit-character-btn')?.addEventListener('click', openEditCharacterModal);
    
    // Character info
    document.getElementById('character-info-btn')?.addEventListener('click', showCharacterInfo);
    
    // Message input
    elements.messageInput?.addEventListener('keydown', handleMessageKeydown);
    elements.sendBtn?.addEventListener('click', sendMessage);
    
    // Auto-resize textarea
    elements.messageInput?.addEventListener('input', autoResizeTextarea);
    
    // Logout
    document.getElementById('logout-btn')?.addEventListener('click', handleLogout);
    
    // Hash change
    window.addEventListener('hashchange', handleHashChange);
}

// User
async function loadCurrentUser() {
    const data = await SynthChat.api.get('/api/auth/me');
    currentUser = data.user;
    
    if (elements.userInfo) {
        elements.userInfo.querySelector('.username').textContent = currentUser.username;
    }
}

async function handleLogout() {
    try {
        await SynthChat.api.post('/api/auth/logout');
        window.location.href = '/login';
    } catch (err) {
        console.error('Logout error:', err);
    }
}

// Sidebar
function toggleSidebar() {
    elements.sidebar?.classList.toggle('open');
    elements.sidebar?.classList.toggle('collapsed');
}

// Characters
async function loadCharacters() {
    try {
        const data = await SynthChat.api.get('/api/characters');
        characters = data.characters;
        renderCharacterList();
        
        if (characters.length === 0) {
            showEmptyState();
        }
    } catch (err) {
        console.error('Error loading characters:', err);
    }
}

function renderCharacterList() {
    if (!elements.characterList) return;
    
    elements.characterList.innerHTML = characters.map(char => `
        <div class="character-card ${currentCharacter?.id === char.id ? 'active' : ''}" 
             data-id="${char.id}" onclick="selectCharacter(${char.id})">
            <img src="${char.avatar_url}" alt="${char.name}" class="avatar">
            <div class="char-info">
                <div class="char-name">${SynthChat.escapeHtml(char.name)}</div>
                <div class="char-desc">${SynthChat.escapeHtml(char.description || char.personality || 'No description')}</div>
            </div>
        </div>
    `).join('');
}

async function selectCharacter(characterId) {
    const character = characters.find(c => c.id === characterId);
    if (!character) return;
    
    currentCharacter = character;
    window.location.hash = `char-${characterId}`;
    
    // Update UI
    renderCharacterList();
    updateChatHeader();
    showChatContainer();
    
    // Show conversations section
    elements.conversationsSection.style.display = 'flex';
    
    // Load conversations
    await loadConversations();
    
    // If no conversations, create one
    if (conversations.length === 0) {
        await createNewConversation();
    } else {
        // Select the most recent conversation
        await selectConversation(conversations[0].id);
    }
}

function updateChatHeader() {
    if (!currentCharacter) return;
    
    elements.currentAvatar.src = currentCharacter.avatar_url;
    elements.currentCharacterName.textContent = currentCharacter.name;
    elements.currentCharacterStatus.textContent = 'Online';
}

function showEmptyState() {
    elements.emptyState.style.display = 'flex';
    elements.chatContainer.style.display = 'none';
    elements.conversationsSection.style.display = 'none';
}

function showChatContainer() {
    elements.emptyState.style.display = 'none';
    elements.chatContainer.style.display = 'flex';
}

// Conversations
async function loadConversations() {
    if (!currentCharacter) return;
    
    try {
        const data = await SynthChat.api.get(`/api/characters/${currentCharacter.id}/conversations`);
        conversations = data.conversations;
        renderConversationList();
    } catch (err) {
        console.error('Error loading conversations:', err);
    }
}

function renderConversationList() {
    if (!elements.conversationList) return;
    
    elements.conversationList.innerHTML = conversations.map(conv => `
        <div class="conversation-item ${currentConversation?.id === conv.id ? 'active' : ''}"
             data-id="${conv.id}" onclick="selectConversation(${conv.id})">
            <span class="material-icons">chat_bubble_outline</span>
            <span class="conv-title">${SynthChat.escapeHtml(conv.title)}</span>
            <span class="conv-date">${SynthChat.formatDate(conv.updated_at)}</span>
        </div>
    `).join('');
}

async function selectConversation(conversationId) {
    try {
        const data = await SynthChat.api.get(`/api/conversations/${conversationId}`);
        currentConversation = data.conversation;
        messages = data.conversation.messages || [];
        
        renderConversationList();
        renderMessages();
        scrollToBottom();
    } catch (err) {
        console.error('Error loading conversation:', err);
    }
}

async function createNewConversation() {
    if (!currentCharacter) return;
    
    try {
        const data = await SynthChat.api.post(`/api/characters/${currentCharacter.id}/conversations`, {
            title: `Chat with ${currentCharacter.name}`
        });
        
        conversations.unshift(data.conversation);
        await selectConversation(data.conversation.id);
    } catch (err) {
        console.error('Error creating conversation:', err);
    }
}

// Messages
function renderMessages() {
    if (!elements.messages) return;
    
    elements.messages.innerHTML = messages.map(msg => `
        <div class="message ${msg.role}">
            ${msg.role === 'assistant' ? 
                `<img src="${currentCharacter?.avatar_url || '/static/avatars/default.png'}" alt="Avatar" class="avatar">` :
                ''
            }
            <div class="message-wrapper">
                <div class="message-content">${formatMessageContent(msg.content)}</div>
                <div class="message-meta">
                    ${msg.emotion && msg.role === 'assistant' ? 
                        `<span class="emotion-badge">${getEmotionEmoji(msg.emotion)} ${msg.emotion}</span>` : 
                        ''
                    }
                    <span>${SynthChat.formatDate(msg.created_at)}</span>
                </div>
            </div>
            ${msg.role === 'user' ? 
                `<img src="/static/avatars/default.png" alt="You" class="avatar">` :
                ''
            }
        </div>
    `).join('');
}

function formatMessageContent(content) {
    // Basic markdown-like formatting
    let formatted = SynthChat.escapeHtml(content);
    
    // Bold: **text**
    formatted = formatted.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    
    // Italic: *text*
    formatted = formatted.replace(/\*(.+?)\*/g, '<em>$1</em>');
    
    // Line breaks
    formatted = formatted.replace(/\n/g, '<br>');
    
    return formatted;
}

function getEmotionEmoji(emotion) {
    const emojis = {
        happy: '😊',
        sad: '😢',
        empathetic: '🤗',
        curious: '🤔',
        helpful: '💡',
        friendly: '😄',
        neutral: '😐',
    };
    return emojis[emotion] || '😐';
}

function scrollToBottom() {
    if (elements.messagesContainer) {
        elements.messagesContainer.scrollTop = elements.messagesContainer.scrollHeight;
    }
}

function autoResizeTextarea() {
    const textarea = elements.messageInput;
    if (!textarea) return;
    
    textarea.style.height = 'auto';
    textarea.style.height = Math.min(textarea.scrollHeight, 150) + 'px';
}

function handleMessageKeydown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
    }
}

async function sendMessage() {
    const content = elements.messageInput?.value.trim();
    if (!content || !currentConversation) return;
    
    // Clear input
    elements.messageInput.value = '';
    elements.messageInput.style.height = 'auto';
    
    // Add user message to UI immediately
    const userMsg = {
        id: Date.now(),
        role: 'user',
        content: content,
        created_at: new Date().toISOString(),
    };
    messages.push(userMsg);
    renderMessages();
    scrollToBottom();
    
    // Show typing indicator
    showTypingIndicator();
    
    try {
        const data = await SynthChat.api.post(`/api/conversations/${currentConversation.id}/messages`, {
            content: content
        });
        
        // Remove typing indicator and add real messages
        hideTypingIndicator();
        
        // Update with real message data
        messages[messages.length - 1] = data.user_message;
        messages.push(data.assistant_message);
        
        renderMessages();
        scrollToBottom();
    } catch (err) {
        console.error('Error sending message:', err);
        hideTypingIndicator();
        
        // Show error message
        const errorMsg = {
            id: Date.now(),
            role: 'assistant',
            content: 'Sorry, I encountered an error. Please try again.',
            emotion: 'neutral',
            created_at: new Date().toISOString(),
        };
        messages.push(errorMsg);
        renderMessages();
        scrollToBottom();
    }
}

function showTypingIndicator() {
    const indicator = document.createElement('div');
    indicator.id = 'typing-indicator';
    indicator.className = 'message assistant';
    indicator.innerHTML = `
        <img src="${currentCharacter?.avatar_url || '/static/avatars/default.png'}" alt="Avatar" class="avatar">
        <div class="typing-indicator">
            <span></span>
            <span></span>
            <span></span>
        </div>
    `;
    elements.messages?.appendChild(indicator);
    scrollToBottom();
}

function hideTypingIndicator() {
    document.getElementById('typing-indicator')?.remove();
}

// Character Modal
function openCreateCharacterModal() {
    resetCharacterForm();
    document.getElementById('modal-title').textContent = 'Create Character';
    document.getElementById('delete-character-btn').style.display = 'none';
    SynthChat.openModal('character-modal');
}

function openEditCharacterModal() {
    if (!currentCharacter) return;
    
    populateCharacterForm(currentCharacter);
    document.getElementById('modal-title').textContent = 'Edit Character';
    document.getElementById('delete-character-btn').style.display = 'block';
    SynthChat.openModal('character-modal');
}

function resetCharacterForm() {
    elements.characterForm?.reset();
    document.getElementById('char-id').value = '';
    document.getElementById('avatar-preview').src = '/static/avatars/default.png';
    document.getElementById('avatar-url').value = '/static/avatars/default.png';
    document.getElementById('temp-value').textContent = '0.7';
}

function populateCharacterForm(character) {
    document.getElementById('char-id').value = character.id;
    document.getElementById('char-name').value = character.name;
    document.getElementById('char-description').value = character.description || '';
    document.getElementById('char-personality').value = character.personality || '';
    document.getElementById('char-system-prompt').value = character.system_prompt || '';
    document.getElementById('char-greeting').value = character.greeting || '';
    document.getElementById('char-model').value = character.model || 'gpt-3.5-turbo';
    document.getElementById('char-temperature').value = character.temperature || 0.7;
    document.getElementById('char-max-tokens').value = character.max_tokens || 500;
    document.getElementById('avatar-preview').src = character.avatar_url || '/static/avatars/default.png';
    document.getElementById('avatar-url').value = character.avatar_url || '/static/avatars/default.png';
    document.getElementById('temp-value').textContent = character.temperature || 0.7;
}

async function handleCharacterFormSubmit(e) {
    e.preventDefault();
    
    const characterId = document.getElementById('char-id').value;
    const isEdit = !!characterId;
    
    const characterData = {
        name: document.getElementById('char-name').value,
        description: document.getElementById('char-description').value,
        personality: document.getElementById('char-personality').value,
        system_prompt: document.getElementById('char-system-prompt').value,
        greeting: document.getElementById('char-greeting').value,
        model: document.getElementById('char-model').value,
        temperature: parseFloat(document.getElementById('char-temperature').value),
        max_tokens: parseInt(document.getElementById('char-max-tokens').value),
        avatar_url: document.getElementById('avatar-url').value,
    };
    
    try {
        SynthChat.showLoading();
        
        let data;
        if (isEdit) {
            data = await SynthChat.api.put(`/api/characters/${characterId}`, characterData);
        } else {
            data = await SynthChat.api.post('/api/characters', characterData);
        }
        
        SynthChat.hideLoading();
        SynthChat.closeModal('character-modal');
        
        await loadCharacters();
        
        if (!isEdit) {
            await selectCharacter(data.character.id);
        } else if (currentCharacter?.id === parseInt(characterId)) {
            currentCharacter = data.character;
            updateChatHeader();
        }
    } catch (err) {
        SynthChat.hideLoading();
        console.error('Error saving character:', err);
        alert(err.message || 'Error saving character');
    }
}

async function handleDeleteCharacter() {
    if (!currentCharacter) return;
    
    const confirmed = confirm(`Are you sure you want to delete ${currentCharacter.name}? This cannot be undone.`);
    if (!confirmed) return;
    
    try {
        SynthChat.showLoading();
        await SynthChat.api.delete(`/api/characters/${currentCharacter.id}`);
        SynthChat.hideLoading();
        SynthChat.closeModal('character-modal');
        
        currentCharacter = null;
        currentConversation = null;
        
        await loadCharacters();
        
        if (characters.length > 0) {
            await selectCharacter(characters[0].id);
        } else {
            showEmptyState();
        }
    } catch (err) {
        SynthChat.hideLoading();
        console.error('Error deleting character:', err);
        alert(err.message || 'Error deleting character');
    }
}

async function handleAvatarUpload(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    
    const formData = new FormData();
    formData.append('file', file);
    
    try {
        SynthChat.showLoading();
        
        const response = await fetch('/api/upload/avatar', {
            method: 'POST',
            body: formData,
            credentials: 'include',
        });
        
        const data = await response.json();
        
        if (response.ok) {
            document.getElementById('avatar-preview').src = data.avatar_url;
            document.getElementById('avatar-url').value = data.avatar_url;
        } else {
            alert(data.error || 'Upload failed');
        }
        
        SynthChat.hideLoading();
    } catch (err) {
        SynthChat.hideLoading();
        console.error('Upload error:', err);
        alert('Error uploading avatar');
    }
}

async function handleGenerateAvatar() {
    const name = document.getElementById('char-name').value || 'Character';
    const personality = document.getElementById('char-personality').value || '';
    
    try {
        SynthChat.showLoading();
        
        const data = await SynthChat.api.post('/api/generate/avatar', {
            name: name,
            use_ai: false,  // Set to true to use AI generation (requires OpenAI API key)
            prompt: `${name}, ${personality}`.substring(0, 200)
        });
        
        document.getElementById('avatar-preview').src = data.avatar_url;
        document.getElementById('avatar-url').value = data.avatar_url;
        
        SynthChat.hideLoading();
    } catch (err) {
        SynthChat.hideLoading();
        console.error('Generation error:', err);
        alert('Error generating avatar');
    }
}

function showCharacterInfo() {
    if (!currentCharacter) return;
    
    const content = document.getElementById('character-info-content');
    if (!content) return;
    
    const traits = currentCharacter.traits || {};
    const traitsList = Object.entries(traits).map(([name, data]) => `
        <div class="trait-tag">
            <span class="trait-name">${SynthChat.escapeHtml(name)}:</span>
            <span class="trait-value">${SynthChat.escapeHtml(data.value || data)}</span>
        </div>
    `).join('') || '<span class="text-muted">No traits yet</span>';
    
    content.innerHTML = `
        <div style="text-align: center; margin-bottom: 20px;">
            <img src="${currentCharacter.avatar_url}" alt="${currentCharacter.name}" 
                 style="width: 100px; height: 100px; border-radius: 50%; object-fit: cover; border: 3px solid var(--accent-primary);">
            <h3 style="margin-top: 12px;">${SynthChat.escapeHtml(currentCharacter.name)}</h3>
        </div>
        
        <div class="char-info-section">
            <h4>Description</h4>
            <p>${SynthChat.escapeHtml(currentCharacter.description) || 'No description'}</p>
        </div>
        
        <div class="char-info-section">
            <h4>Personality</h4>
            <p>${SynthChat.escapeHtml(currentCharacter.personality) || 'No personality defined'}</p>
        </div>
        
        <div class="char-info-section">
            <h4>Character Traits</h4>
            <div class="traits-list">${traitsList}</div>
        </div>
        
        <div class="char-info-section">
            <h4>Stats</h4>
            <p>
                <strong>Conversations:</strong> ${currentCharacter.conversation_count || 0}<br>
                <strong>Model:</strong> ${currentCharacter.model}<br>
                <strong>Temperature:</strong> ${currentCharacter.temperature}<br>
                <strong>Google Drive:</strong> ${currentCharacter.drive_connected ? '✓ Connected' : '✗ Not connected'}
            </p>
        </div>
    `;
    
    SynthChat.openModal('character-info-modal');
}

// Handle URL hash changes
function handleHashChange() {
    const hash = window.location.hash;
    
    if (hash === '#create') {
        openCreateCharacterModal();
        window.location.hash = '';
    } else if (hash.startsWith('#char-')) {
        const charId = parseInt(hash.replace('#char-', ''));
        if (charId && (!currentCharacter || currentCharacter.id !== charId)) {
            selectCharacter(charId);
        }
    }
}

// Make functions available globally
window.selectCharacter = selectCharacter;
window.selectConversation = selectConversation;
