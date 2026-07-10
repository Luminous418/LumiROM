// ─── LumiROM Changelog Data ───────────────────────────────────────────────────

const CHANGELOGS = [
    {
        version: '8.6.2', series: '8.6.x', tag: 'latest', date: '2026-05',
        sections: {
            fixes: ['No fixes in this release.'],
            features: [
                'Added a ton of AI that hasn\'t been present in the ROM until now, like Now Brief, Now Nudge, Weather Wallpaper and more. Be sure to check them all out!'
            ],
            bugs: [
                'For some users, calling and receiving calls may not sound. Known issue related to kernel.',
                'Some camera modes like 0.5x.'
            ],
            more: [
                'Most of the fixes have been added onto the script. Working hard to add more features and make the scripts more stable and user-friendly.',
                'Added color to script for better understanding.',
                'Added a builder for local use with a cache system - firmware is downloaded only once.',
                'Added a new script, cache_manager.sh, with commands like status, check, clear, size and list to manage the cache of the imgs.'
            ]
        }
    },
    {
        version: '8.6.1', series: '8.6.x', tag: 'stable', date: '2026-04',
        sections: {
            fixes: [
                'Fixed apps crashing like X, Snapchat; others that were significantly laggy like Telegram.',
                'Fixed QS and UI lag - should be smoother now.',
                'Fixed VoLTE.'
            ],
            features: [
                'Added new wallpapers - check the wallpapers app, select a wallpaper, choose default, then tap "Other styles" for S26 walls and more.',
                'Added stock props for better performance on daily based tasks.',
                'Added mods to quick panel - now more resizable!',
                'Added A226B (Galaxy A22 5G) support as OFFICIAL builds.'
            ],
            deviceSpecific: [
                'New A34 base: A346BXXUFFZD5 with 05-04-2026 security patch.',
                'New A24 base: A245FXXUBFZD1 with 05-04-2026 security patch.'
            ],
            more: ['Removed Samsung Messages and replaced with Google Messages.'],
            bugs: ['You tell me.']
        }
    },
    {
        version: '8.6.0', series: '8.6.x', tag: 'stable', date: '2026-03',
        sections: {
            fixes: [
                'Fixed hotspot on A32 and A22 devices (turns on but won\'t turn off).',
                'Fixed Bluetooth on A15 base for side-FP devices.',
                'Fixed some related issues with Gallery.',
                'Added Gallery AI with proper fixes.'
            ],
            bugs: ['You tell me.']
        }
    },
    {
        version: '8.5.5', series: '8.5.x', tag: 'stable', date: '2025-12',
        sections: {
            fixes: [
                'Fixed SSRM warnings when booting the phone.',
                'Fixed Knox services like Secure Folder.',
                'Fixed portrait on Samsung Camera.',
                'Fixed overlay - was a bit buggy on some scenarios.'
            ],
            features: ['Massive debloat.'],
            deviceSpecific: [
                'A32 got a new kernel with spoofed 5.10 (visual).',
                'A22 got a new kernel with spoofed 6.12 (visual).'
            ],
            bugs: ['Hotspot does not work yet.', 'You tell me.']
        }
    },
    {
        version: '8.5.0', series: '8.5.x', tag: 'beta', date: '2025-11',
        sections: {
            fixes: ['Fixed RIL.', 'Fixed Camera (almost).', 'Fixed SSRM (background crash).', 'Fixed NFC.', 'Fixed FOD.'],
            more: ['First One UI 8.5 from A34 base. Expect bugs, but should be suitable for daily use.'],
            bugs: ['Some camera modes like portrait are not working.', 'You tell me.']
        }
    },
    {
        version: '8.3.1', series: '8.3.x', tag: 'stable', date: '2025-10',
        sections: {
            fixes: ['Fixed recent calls on Phone app.', 'Fixed Studio app.'],
            features: ['Removed FRP.', 'Added AI Weather on Lockscreen.', 'Added AI Wallpaper.', 'Added new game settings.'],
            more: ['LumiVENDOR is now mandatory - keep it on storage until a new update comes out.', 'Report bugs on the bug theme on the group.'],
            bugs: ['Fix Camera green on portrait.']
        }
    },
    {
        version: '8.3.0', series: '8.3.x', tag: 'stable', date: '2025-09',
        sections: {
            fixes: ['Fixed Now Brief.', 'Fixed clock selection on lockscreen.'],
            features: [
                'Product, system_ext, odm and vendor converted to EROFS.',
                'Added prism partition.',
                'Added new kernel to boot EROFS on A32 and A22.',
                'December security patch.',
                'Added One UI 8.5 APKs.'
            ],
            deviceSpecific: ['(A22) Fixed NFC.', '(A22) Fixed hotspot bug.'],
            more: [
                'LumiVENDOR has been updated - install the new version; device won\'t boot without it.',
                'Don\'t change kernel. Use the default kernel. If you want root, use Magisk; KernelSU / SukiSU won\'t work as they aren\'t updated.'
            ],
            bugs: ['You tell me.']
        }
    },
    {
        version: '8.2.5', series: '8.2.x', tag: 'stable', date: '2025-06',
        deviceNote: 'Only for A32',
        sections: {
            fixes: ['Fixed accessibility.'],
            more: [
                'New way to flash the ROM - now split into 2 parts: the ROM itself, and vendors & kernels.',
                'ROM size reduced from ~4.15 GB to ~3 GB (without vendors).',
                'Vendors and kernel don\'t need to be reflashed after every update if already installed.'
            ]
        }
    },
    {
        version: '8.2.0', series: '8.2.x', tag: 'stable', date: '2025-05',
        sections: {
            fixes: ['Fixed VoLTE.'],
            features: ['Added Galaxy Themes (was accidentally debloated).'],
            more: ['Added support for: A325FXXSCDYB2, A325FXXSCDXL2, A325FXXS7DWL1, A325MUBSBDYC2, M325FVXXSCDYD1.']
        }
    },
    {
        version: '8.1.1', series: '8.1.x', tag: 'stable', date: '2025-04',
        sections: {
            fixes: ['Fixed SSRM Warning.', 'Fixed portrait camera.', 'Fixed One UI Home crash (again).'],
            features: ['Added Edge Panel as launcher fix.', 'Added new up_param.']
        }
    },
    {
        version: '8.1.0', series: '8.1.x', tag: 'beta', date: '2025-03',
        sections: {
            fixes: ['Fixed One UI Home crash.', 'Fixed some background crashes.', 'First attempt to fix battery backup - should be way better now.'],
            features: ['Added Samsung AI features.'],
            more: ['ROM should now be stable for daily use.']
        }
    },
    {
        version: '8.0.1', series: '8.0.x', tag: 'alpha', date: '2025-02',
        sections: { fixes: ['Fixed system sound.'] }
    },
    {
        version: '8.0.0', series: '8.0.x', tag: 'alpha', date: '2025-01',
        sections: {
            fixes: ['FOD.', 'Wallpaper change.', 'NFC.', 'Basic features like Wi-Fi and Bluetooth.', 'Lag on security settings.'],
            bugs: ['SSRM warning (hard to fix).', 'Some things can lag.', 'Can\'t change system sounds volume.'],
            more: ['FORMAT DATA required.', 'First One UI 8 port. Not fully intended for daily usage - most annoying issue is system volume.']
        }
    }
];

// ─── Section Metadata ─────────────────────────────────────────────────────────
const SECTION_META = {
    fixes:         { label: 'Fixes',           icon: '🔧', color: '#22c55e' },
    features:      { label: 'New Features',    icon: '✨', color: '#3b82f6' },
    bugs:          { label: 'Known Bugs',      icon: '🐛', color: '#f59e0b' },
    deviceSpecific:{ label: 'Device Specific', icon: '📱', color: '#06b6d4' },
    more:          { label: 'More Info',       icon: 'ℹ️', color: '#94a3b8' },
    notes:         { label: 'Notes',           icon: '📝', color: '#a855f7' }
};

const TAG_META = {
    latest: { label: 'Latest', color: '#22c55e' },
    stable: { label: 'Stable', color: '#22c55e' },
    beta:   { label: 'Beta',   color: '#f59e0b' },
    alpha:  { label: 'Alpha',  color: '#06b6d4' }
};

// ─── Renderer ─────────────────────────────────────────────────────────────────
function renderChangelog(cl) {
    const tagHtml = cl.tag
        ? `<span class="cl-tag" style="background:${TAG_META[cl.tag].color}22;color:${TAG_META[cl.tag].color};border-color:${TAG_META[cl.tag].color}44;">${TAG_META[cl.tag].label}</span>`
        : '';

    const deviceNoteHtml = cl.deviceNote
        ? `<div class="cl-device-note">⚠️ ${cl.deviceNote}</div>`
        : '';

    const sectionsHtml = Object.entries(cl.sections).map(([key, items]) => {
        const meta = SECTION_META[key] || { label: key, icon: '•', color: '#94a3b8' };
        const itemsHtml = items.map(item => `<li>${item}</li>`).join('');
        return `
        <div class="cl-section" style="--section-color:${meta.color}">
            <div class="cl-section-header">
                <span class="cl-section-icon">${meta.icon}</span>
                <h3 class="cl-section-title">${meta.label}</h3>
            </div>
            <ul class="cl-list">${itemsHtml}</ul>
        </div>`;
    }).join('');

    return `
    <div class="cl-hero">
        <div class="cl-hero-top">
            <div>
                <div class="cl-version-label">LumiROM <span>${cl.version}</span></div>
                <div class="cl-series">Series ${cl.series} · ${cl.date}</div>
            </div>
            <div class="cl-hero-actions">
                ${tagHtml}
                <a href="https://t.me/LumiROMs" target="_blank" class="cl-download-btn">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                         stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
                    </svg>
                    Download on Telegram
                </a>
            </div>
        </div>
        ${deviceNoteHtml}
    </div>
    <div class="cl-sections">${sectionsHtml}</div>`;
}

// ─── Init ─────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    const sidebar = document.getElementById('cl-sidebar');
    const panel   = document.getElementById('cl-panel');
    if (!sidebar || !panel) return;

    // Build sidebar version list
    let currentSeries = null;
    CHANGELOGS.forEach((cl, idx) => {
        if (cl.series !== currentSeries) {
            currentSeries = cl.series;
            const heading = document.createElement('div');
            heading.className = 'cl-series-heading';
            heading.textContent = `Series ${cl.series}`;
            sidebar.appendChild(heading);
        }

        const item = document.createElement('button');
        item.className = 'cl-sidebar-item' + (idx === 0 ? ' active' : '');
        item.dataset.idx = idx;

        const tagDot = cl.tag
            ? `<span class="cl-tag-dot" style="background:${TAG_META[cl.tag].color};"></span>`
            : '';

        item.innerHTML = `
            <span class="cl-item-version">${tagDot}${cl.version}</span>
            <span class="cl-item-date">${cl.date}</span>`;

        item.addEventListener('click', () => {
            document.querySelectorAll('.cl-sidebar-item').forEach(b => b.classList.remove('active'));
            item.classList.add('active');

            panel.style.opacity = '0';
            panel.style.transform = 'translateY(10px)';
            setTimeout(() => {
                panel.innerHTML = renderChangelog(CHANGELOGS[idx]);
                panel.style.opacity = '1';
                panel.style.transform = 'translateY(0)';
            }, 160);
        });

        sidebar.appendChild(item);
    });

    // Render first entry
    panel.innerHTML = renderChangelog(CHANGELOGS[0]);
    panel.style.transition = 'opacity 0.2s ease, transform 0.2s ease';
});
