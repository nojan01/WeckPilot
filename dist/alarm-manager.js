/**
 * Alarm Manager
 * Verwaltet alle Alarme (CRUD-Operationen)
 */

const AlarmManager = (function() {
    const STORAGE_KEY = 'wecker-app-alarms';
    let alarms = [];

    /**
     * UUID generieren
     */
    function generateId() {
        return 'alarm-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    }

    /**
     * Alarme aus Storage laden
     */
    function loadAlarms() {
        alarms = Storage.get(STORAGE_KEY) || [];
        return alarms;
    }

    /**
     * Alarme in Storage speichern
     */
    function saveAlarms() {
        Storage.set(STORAGE_KEY, alarms);
    }

    /**
     * Alle Alarme abrufen
     */
    function getAlarms() {
        if (alarms.length === 0) {
            loadAlarms();
        }
        return [...alarms].sort((a, b) => a.time.localeCompare(b.time));
    }

    /**
     * Einzelnen Alarm abrufen
     */
    function getAlarm(id) {
        return alarms.find(a => a.id === id);
    }

    /**
     * Neuen Alarm hinzufügen
     */
    function addAlarm(alarmData) {
        const alarm = {
            id: generateId(),
            time: alarmData.time || '07:00',
            label: alarmData.label || '',
            enabled: alarmData.enabled !== false,
            repeatType: alarmData.repeatType || 'recurring',
            days: alarmData.days || ['mo', 'di', 'mi', 'do', 'fr'],
            sound: alarmData.sound || 'alarm1',
            volume: {
                start: alarmData.volume?.start ?? 0.1,
                end: alarmData.volume?.end ?? 1.0,
                duration: alarmData.volume?.duration ?? 30
            },
            snooze: {
                enabled: alarmData.snooze?.enabled !== false,
                duration: alarmData.snooze?.duration || 5
            },
            createdAt: new Date().toISOString()
        };

        alarms.push(alarm);
        saveAlarms();
        
        return alarm;
    }

    /**
     * Alarm aktualisieren
     */
    function updateAlarm(id, updates) {
        const index = alarms.findIndex(a => a.id === id);
        if (index === -1) return null;

        alarms[index] = {
            ...alarms[index],
            ...updates,
            volume: {
                ...alarms[index].volume,
                ...(updates.volume || {})
            },
            snooze: {
                ...alarms[index].snooze,
                ...(updates.snooze || {})
            },
            repeatType: updates.repeatType || alarms[index].repeatType || 'recurring',
            updatedAt: new Date().toISOString()
        };

        saveAlarms();
        return alarms[index];
    }

    /**
     * Alarm löschen
     */
    function deleteAlarm(id) {
        const index = alarms.findIndex(a => a.id === id);
        if (index === -1) return false;

        alarms.splice(index, 1);
        saveAlarms();
        return true;
    }

    /**
     * Alarm aktivieren/deaktivieren
     */
    function toggleAlarm(id) {
        const alarm = getAlarm(id);
        if (!alarm) return null;

        return updateAlarm(id, { enabled: !alarm.enabled });
    }

    /**
     * Nächsten aktiven Alarm ermitteln
     */
    function getNextAlarm() {
        const now = new Date();
        const currentDay = ['so', 'mo', 'di', 'mi', 'do', 'fr', 'sa'][now.getDay()];
        const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
        
        const activeAlarms = alarms.filter(a => a.enabled && a.days.length > 0);
        
        if (activeAlarms.length === 0) return null;

        // Sortiere nach Zeit
        const sorted = activeAlarms.sort((a, b) => a.time.localeCompare(b.time));
        
        // Finde den nächsten Alarm für heute
        for (const alarm of sorted) {
            if (alarm.days.includes(currentDay) && alarm.time > currentTime) {
                return alarm;
            }
        }

        // Kein Alarm mehr heute, finde den ersten für morgen oder später
        const dayOrder = ['so', 'mo', 'di', 'mi', 'do', 'fr', 'sa'];
        const currentDayIndex = dayOrder.indexOf(currentDay);
        
        for (let i = 1; i <= 7; i++) {
            const checkDayIndex = (currentDayIndex + i) % 7;
            const checkDay = dayOrder[checkDayIndex];
            
            for (const alarm of sorted) {
                if (alarm.days.includes(checkDay)) {
                    return alarm;
                }
            }
        }

        return sorted[0]; // Fallback
    }

    /**
     * Alle Alarme löschen
     */
    function clearAllAlarms() {
        alarms = [];
        saveAlarms();
    }

    /**
     * Alarme exportieren
     */
    function exportAlarms() {
        return JSON.stringify(alarms, null, 2);
    }

    /**
     * Alarme importieren
     */
    function importAlarms(jsonString) {
        try {
            const imported = JSON.parse(jsonString);
            if (!Array.isArray(imported)) {
                throw new Error('Ungültiges Format');
            }
            
            alarms = imported.map(a => ({
                ...a,
                id: a.id || generateId()
            }));
            
            saveAlarms();
            return true;
        } catch (error) {
            console.error('Import fehlgeschlagen:', error);
            return false;
        }
    }

    // Initialisierung
    loadAlarms();

    // Public API
    return {
        getAlarms,
        getAlarm,
        addAlarm,
        updateAlarm,
        deleteAlarm,
        toggleAlarm,
        getNextAlarm,
        clearAllAlarms,
        exportAlarms,
        importAlarms
    };
})();
