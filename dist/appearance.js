/** Persisted color profiles and proportional window sizing. */
(() => {
    const root = document.documentElement;
    const profileSelect = document.getElementById('color-profile');
    const scaleSelect = document.getElementById('interface-scale');
    const status = document.getElementById('appearance-status');
    const profiles = ['blue', 'amber', 'red', 'green', 'mono'];
    const scales = [70, 80, 90, 100, 110, 120, 130, 140, 150];
    const storageKey = 'weckpilot-appearance';
    let saved = {};
    try { saved = JSON.parse(localStorage.getItem(storageKey)) || {}; } catch (_) {}
    let profile = profiles.includes(saved.profile) ? saved.profile : 'blue';
    let scale = 100;
    function persist() {
        try { localStorage.setItem(storageKey, JSON.stringify({ profile, scale })); } catch (_) {}
    }
    function applyProfile(value) {
        profile = profiles.includes(value) ? value : 'blue';
        root.dataset.profile = profile;
        profileSelect.value = profile;
    }
    async function applyScale(value) {
        const requested = scales.includes(value) ? value : 100;
        scaleSelect.disabled = true;
        status.textContent = '';
        try {
            const api = window.__TAURI__;
            if (api) {
                const monitor = await api.window.currentMonitor();
                const area = monitor?.workArea?.size ?? monitor?.size;
                const factor = monitor?.scaleFactor ?? 1;
                const available = area ? Math.min(area.width / factor / 700, area.height / factor / 650) * 100 : 150;
                const fitting = scales.filter(item => item <= available);
                const effective = Math.min(requested, fitting.at(-1) ?? 70);
                // Apply CSS zoom only after native resizing succeeds.
                await api.window.getCurrentWindow().setSize(new api.dpi.LogicalSize(700 * effective / 100, 650 * effective / 100));
                scale = effective;
            } else {
                scale = requested;
            }
            root.style.zoom = String(scale / 100);
            persist();
        } catch (error) {
            console.error('Appearance resize failed:', error);
            status.textContent = I18n.t('scaleFailed');
        } finally {
            scaleSelect.value = String(scale);
            scaleSelect.disabled = false;
        }
    }
    applyProfile(profile);
    profileSelect.addEventListener('change', () => { applyProfile(profileSelect.value); persist(); });
    scaleSelect.addEventListener('change', () => applyScale(Number(scaleSelect.value)));
    applyScale(saved.scale);
})();
