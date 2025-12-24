/**
 * SynthChat - Main Application JavaScript
 */

// API Helper
const api = {
    async request(url, options = {}) {
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
            },
            credentials: 'include',
        };
        
        const response = await fetch(url, { ...defaultOptions, ...options });
        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || 'Request failed');
        }
        
        return data;
    },
    
    get(url) {
        return this.request(url);
    },
    
    post(url, body) {
        return this.request(url, {
            method: 'POST',
            body: JSON.stringify(body),
        });
    },
    
    put(url, body) {
        return this.request(url, {
            method: 'PUT',
            body: JSON.stringify(body),
        });
    },
    
    delete(url) {
        return this.request(url, { method: 'DELETE' });
    },
};

// Loading overlay control
function showLoading() {
    document.getElementById('loading-overlay')?.classList.add('active');
}

function hideLoading() {
    document.getElementById('loading-overlay')?.classList.remove('active');
}

// Modal helper
function openModal(modalId) {
    document.getElementById(modalId)?.classList.add('active');
}

function closeModal(modalId) {
    document.getElementById(modalId)?.classList.remove('active');
}

// Initialize modal close handlers
document.addEventListener('DOMContentLoaded', () => {
    // Close modals on overlay click
    document.querySelectorAll('.modal-overlay').forEach(overlay => {
        overlay.addEventListener('click', () => {
            overlay.closest('.modal').classList.remove('active');
        });
    });
    
    // Close modals on close button click
    document.querySelectorAll('.modal-close').forEach(btn => {
        btn.addEventListener('click', () => {
            btn.closest('.modal').classList.remove('active');
        });
    });
    
    // Close modals on Escape key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            document.querySelectorAll('.modal.active').forEach(modal => {
                modal.classList.remove('active');
            });
        }
    });
});

// Format date helper
function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    
    return date.toLocaleDateString();
}

// Escape HTML helper
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Export utilities
window.SynthChat = {
    api,
    showLoading,
    hideLoading,
    openModal,
    closeModal,
    formatDate,
    escapeHtml,
};
