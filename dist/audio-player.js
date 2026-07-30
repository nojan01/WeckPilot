/**
 * Audio Player - Mit vielen verschiedenen Wecktönen
 * Verwendet Web Audio API für oszillatorbasierte Sounds
 */

const AudioPlayer = (function() {
    let audioContext = null;
    let gainNode = null;
    let isPlaying = false;
    let volumeInterval = null;
    let oscillators = [];
    let playInterval = null;

    // Viele verschiedene Wecktöne
    const SOUNDS = {
        'gentle-rise': {
            name: '🌅 Gentle Rise',
            type: 'sine',
            frequencies: [262, 330, 392, 523],
            tempo: 500,
            pattern: 'ascending'
        },
        'morning-birds': {
            name: '🐦 Morning Birds',
            type: 'sine',
            frequencies: [1047, 1175, 1319, 1397, 1319, 1175],
            tempo: 150,
            pattern: 'random'
        },
        'ocean-waves': {
            name: '🌊 Ocean Waves',
            type: 'sine',
            frequencies: [110, 130, 165, 196],
            tempo: 800,
            pattern: 'wave'
        },
        'wind-chimes': {
            name: '🎐 Wind Chimes',
            type: 'sine',
            frequencies: [523, 659, 784, 880, 1047],
            tempo: 300,
            pattern: 'random'
        },
        'soft-piano': {
            name: '🎹 Soft Piano',
            type: 'sine',
            frequencies: [262, 294, 330, 349, 392, 440, 494, 523],
            tempo: 400,
            pattern: 'ascending'
        },
        'zen-bells': {
            name: '🔔 Zen Bells',
            type: 'sine',
            frequencies: [440, 554, 659],
            tempo: 1200,
            pattern: 'sequence'
        },
        'digital-beep': {
            name: '📟 Digital Beep',
            type: 'square',
            frequencies: [880, 0, 880, 0, 880],
            tempo: 200,
            pattern: 'sequence'
        },
        'classic-alarm': {
            name: '⏰ Classic Alarm',
            type: 'square',
            frequencies: [660, 880],
            tempo: 150,
            pattern: 'alternate'
        },
        'rooster': {
            name: '🐓 Rooster',
            type: 'sawtooth',
            frequencies: [220, 330, 440, 550, 660, 880, 660, 440],
            tempo: 100,
            pattern: 'sequence'
        },
        'harp': {
            name: '🎵 Harp',
            type: 'sine',
            frequencies: [262, 294, 330, 349, 392, 440, 494, 523, 587, 659],
            tempo: 120,
            pattern: 'ascending'
        }
    };

    function initAudioContext() {
        if (!audioContext || audioContext.state === 'closed') {
            audioContext = new (window.AudioContext || window.webkitAudioContext)();
        }
        if (audioContext.state === 'suspended') {
            audioContext.resume();
        }
        return audioContext;
    }

    function createOscillator(type, frequency, duration = 0.3) {
        const ctx = initAudioContext();
        const osc = ctx.createOscillator();
        const oscGain = ctx.createGain();
        
        osc.type = type;
        osc.frequency.setValueAtTime(frequency, ctx.currentTime);
        
        // Envelope für Sound
        oscGain.gain.setValueAtTime(0, ctx.currentTime);
        oscGain.gain.linearRampToValueAtTime(0.8, ctx.currentTime + 0.02);
        oscGain.gain.linearRampToValueAtTime(0, ctx.currentTime + duration);
        
        osc.connect(oscGain);
        oscGain.connect(gainNode);
        
        osc.start();
        osc.stop(ctx.currentTime + duration);
        
        return osc;
    }

    function playAlarm(soundType, options = {}) {
        const startVolume = options.startVolume ?? 0.1;
        const endVolume = options.endVolume ?? 1.0;
        const duration = options.duration ?? 30;

        stop();

        const ctx = initAudioContext();
        const sound = SOUNDS[soundType] || SOUNDS['gentle-rise'];
        
        gainNode = ctx.createGain();
        gainNode.gain.setValueAtTime(startVolume, ctx.currentTime);
        gainNode.connect(ctx.destination);

        isPlaying = true;
        let noteIndex = 0;

        function getNextFrequency() {
            const freqs = sound.frequencies;
            switch (sound.pattern) {
                case 'random':
                    return freqs[Math.floor(Math.random() * freqs.length)];
                case 'alternate':
                    return freqs[noteIndex % 2];
                case 'wave':
                    const waveIdx = Math.floor(noteIndex / 2) % freqs.length;
                    return freqs[noteIndex % 2 === 0 ? waveIdx : freqs.length - 1 - waveIdx];
                case 'ascending':
                case 'sequence':
                default:
                    return freqs[noteIndex % freqs.length];
            }
        }

        function playNextNote() {
            if (!isPlaying) return;

            const frequency = getNextFrequency();
            
            if (frequency > 0) {
                const osc = createOscillator(sound.type, frequency, sound.tempo / 1000 * 0.8);
                oscillators.push(osc);
            }

            noteIndex++;
        }

        // Start playing
        playNextNote();
        playInterval = setInterval(playNextNote, sound.tempo);

        // Volume fade
        if (duration > 0) {
            const volumeStep = (endVolume - startVolume) / (duration * 10);
            let currentVolume = startVolume;

            volumeInterval = setInterval(() => {
                if (!isPlaying || currentVolume >= endVolume) {
                    if (volumeInterval) {
                        clearInterval(volumeInterval);
                        volumeInterval = null;
                    }
                    return;
                }

                currentVolume = Math.min(currentVolume + volumeStep, endVolume);
                if (gainNode && audioContext) {
                    gainNode.gain.setValueAtTime(currentVolume, audioContext.currentTime);
                }
            }, 100);
        }
    }

    function stop() {
        isPlaying = false;

        if (playInterval) {
            clearInterval(playInterval);
            playInterval = null;
        }

        if (volumeInterval) {
            clearInterval(volumeInterval);
            volumeInterval = null;
        }

        oscillators.forEach(osc => {
            try { osc.stop(); } catch(e) {}
        });
        oscillators = [];

        if (gainNode) {
            try {
                if (audioContext && audioContext.state !== 'closed') {
                    gainNode.gain.setValueAtTime(0, audioContext.currentTime);
                }
                gainNode.disconnect();
            } catch (e) {}
            gainNode = null;
        }

        // AudioContext schließen und zurücksetzen für zuverlässige Wiedergabe beim nächsten Alarm
        if (audioContext) {
            try {
                audioContext.close();
            } catch (e) {}
            audioContext = null;
        }
    }

    function preview(soundType) {
        stop();

        const ctx = initAudioContext();
        const sound = SOUNDS[soundType] || SOUNDS['gentle-rise'];

        gainNode = ctx.createGain();
        gainNode.gain.setValueAtTime(0.6, ctx.currentTime);
        gainNode.connect(ctx.destination);

        isPlaying = true;
        let noteIndex = 0;
        const maxNotes = Math.min(sound.frequencies.length, 6);
        
        function playNote() {
            if (noteIndex >= maxNotes || !isPlaying) {
                stop();
                return;
            }

            const frequency = sound.frequencies[noteIndex % sound.frequencies.length];
            
            if (frequency > 0) {
                const osc = createOscillator(sound.type, frequency, 0.25);
                oscillators.push(osc);
            }

            noteIndex++;
            setTimeout(playNote, 250);
        }

        playNote();
    }

    function getAvailableSounds() {
        return Object.entries(SOUNDS).map(([id, sound]) => ({
            id,
            name: sound.name
        }));
    }

    function isCurrentlyPlaying() {
        return isPlaying;
    }

    return {
        playAlarm,
        stop,
        preview,
        getAvailableSounds,
        isPlaying: isCurrentlyPlaying
    };
})();
