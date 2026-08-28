/**
 * Storage Manager
 * Verwaltet die lokale Speicherung der Alarme
 */

const Storage = (function() {
    const PREFIX = 'wecker-app-';

    /**
     * Prüfen ob localStorage verfügbar ist
     */
    function isAvailable() {
        try {
            const test = '__storage_test__';
            localStorage.setItem(test, test);
            localStorage.removeItem(test);
            return true;
        } catch (e) {
            return false;
        }
    }

    /**
     * Daten speichern
     */
    function set(key, value) {
        if (!isAvailable()) {
            console.warn('LocalStorage is unavailable');
            return false;
        }

        try {
            const serialized = JSON.stringify(value);
            localStorage.setItem(PREFIX + key, serialized);
            return true;
        } catch (error) {
            console.error('Save error:', error);
            return false;
        }
    }

    /**
     * Daten abrufen
     */
    function get(key) {
        if (!isAvailable()) {
            console.warn('LocalStorage is unavailable');
            return null;
        }

        try {
            const item = localStorage.getItem(PREFIX + key);
            return item ? JSON.parse(item) : null;
        } catch (error) {
            console.error('Load error:', error);
            return null;
        }
    }

    /**
     * Daten löschen
     */
    function remove(key) {
        if (!isAvailable()) return false;

        try {
            localStorage.removeItem(PREFIX + key);
            return true;
        } catch (error) {
            console.error('Delete error:', error);
            return false;
        }
    }

    /**
     * Alle App-Daten löschen
     */
    function clear() {
        if (!isAvailable()) return false;

        try {
            const keys = Object.keys(localStorage).filter(k => k.startsWith(PREFIX));
            keys.forEach(k => localStorage.removeItem(k));
            return true;
        } catch (error) {
            console.error('Delete error:', error);
            return false;
        }
    }

    /**
     * Alle gespeicherten Schlüssel abrufen
     */
    function keys() {
        if (!isAvailable()) return [];

        return Object.keys(localStorage)
            .filter(k => k.startsWith(PREFIX))
            .map(k => k.replace(PREFIX, ''));
    }

    /**
     * Speichernutzung berechnen
     */
    function getUsage() {
        if (!isAvailable()) return { used: 0, available: 0 };

        let totalSize = 0;
        for (const key of Object.keys(localStorage)) {
            if (key.startsWith(PREFIX)) {
                totalSize += localStorage.getItem(key).length * 2; // UTF-16
            }
        }

        return {
            used: totalSize,
            usedFormatted: formatBytes(totalSize),
            available: 5 * 1024 * 1024, // ~5MB typisch
            availableFormatted: '5 MB'
        };
    }

    /**
     * Bytes formatieren
     */
    function formatBytes(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    // Public API
    return {
        isAvailable,
        set,
        get,
        remove,
        clear,
        keys,
        getUsage
    };
})();
