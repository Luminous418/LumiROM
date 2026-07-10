/* ===================================================================
   LumiROM Documentation - Main JS
   =================================================================== */

document.addEventListener('DOMContentLoaded', () => {

    // ── Copy buttons for <pre> blocks ──────────────────────────────
    document.querySelectorAll('pre').forEach(pre => {
        // Don't add button if already has one
        if (pre.querySelector('.copy-btn')) return;

        const btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.textContent = 'COPY';
        btn.addEventListener('click', () => {
            const text = pre.innerText.replace(/COPY$/, '').trim();
            navigator.clipboard.writeText(text).then(() => {
                btn.textContent = 'COPIED!';
                setTimeout(() => { btn.textContent = 'COPY'; }, 2000);
            }).catch(() => {});
        });
        pre.appendChild(btn);
    });

    // ── Terminal block copy buttons ────────────────────────────────
    document.querySelectorAll('.copy-term-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const block = btn.closest('.terminal-block');
            const codeEl = block ? block.querySelector('code') : null;
            if (!codeEl) return;
            navigator.clipboard.writeText(codeEl.textContent.trim()).then(() => {
                const orig = btn.textContent;
                btn.textContent = 'Copied!';
                setTimeout(() => { btn.textContent = orig; }, 2000);
            });
        });
    });

    // ── Feature tabs ───────────────────────────────────────────────
    const tabBtns = document.querySelectorAll('.tab-btn[data-tab]');
    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            // Deactivate all in the same .tab-bar
            const bar = btn.closest('.tab-bar');
            if (bar) {
                bar.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            } else {
                tabBtns.forEach(b => b.classList.remove('active'));
            }
            btn.classList.add('active');

            // Hide all tab-content, show target
            const targetId = `tab-${btn.dataset.tab}`;
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            const target = document.getElementById(targetId);
            if (target) target.classList.add('active');
        });
    });

    // ── Guide tabs (build page) ────────────────────────────────────
    const guideBtns = document.querySelectorAll('.guide-tab-btn');
    guideBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            guideBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            document.querySelectorAll('.guide-panel').forEach(p => p.classList.remove('active'));
            const target = document.getElementById(`guide-${btn.dataset.guide}`);
            if (target) target.classList.add('active');
        });
    });

    // ── Device search filter ────────────────────────────────────────
    const deviceSearch = document.getElementById('device-search');
    if (deviceSearch) {
        deviceSearch.addEventListener('input', e => {
            const q = e.target.value.toLowerCase().trim();
            document.querySelectorAll('.device-card-item').forEach(card => {
                const name  = (card.dataset.device || '').toLowerCase();
                const model = (card.dataset.model  || '').toLowerCase();
                card.style.display = (name.includes(q) || model.includes(q)) ? '' : 'none';
            });
        });
    }

    // ── Cache terminal simulator ────────────────────────────────────
    const cacheOutputs = {
        status: `[CACHE STATUS]\nChecking firmware cache directory...\nCache status: ENABLED\nTotal firmware versions cached: 3\nLatest build cached: SM-A346B (One UI 8.5)\nIntegrity check: PASS`,
        check:  `[CACHE VERIFICATION]\nVerifying required partition images...\nChecking system.img... OK\nChecking vendor.img... OK\nChecking product.img... OK\nAll required images verified and ready for patching.`,
        size:   `[CACHE SIZE]\nCalculating cache size...\nLocation: IMGs/\nFiles count: 6\nTotal space used: 4.82 GiB`,
        list:   `[CACHE LIST]\nListing all cached images with sizes:\n- system.img              4.92 GiB  (Modified: 2026-05-18)\n- vendor.img              680 MiB   (Modified: 2026-05-18)\n- product.img             1.65 GiB  (Modified: 2026-05-15)\n- system_ext.img          620 MiB   (Modified: 2026-05-15)\nTotal cached firmware builds: 4`,
        clear:  `[CACHE WIPE]\nClearing cached firmware images...\nDeleting cache files from IMGs/...\nOperation completed successfully.\nCache status: Empty (0 B)`
    };

    const cacheOutput = document.getElementById('cache-output');
    document.querySelectorAll('.btn-cache').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.btn-cache').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            const cmd = btn.dataset.cmd;
            if (cacheOutput && cacheOutputs[cmd]) {
                cacheOutput.innerHTML =
                    `<span class="terminal-prompt">$</span><span class="terminal-cmd"> bash scripts/cache_manager.sh ${cmd}</span>\n<span class="terminal-output">${cacheOutputs[cmd]}</span>`;
            }
        });
    });

    // Cache copy button
    const cacheCopyBtn = document.getElementById('cache-copy-btn');
    if (cacheCopyBtn && cacheOutput) {
        cacheCopyBtn.addEventListener('click', () => {
            const cmdEl = cacheOutput.querySelector('.terminal-cmd');
            if (!cmdEl) return;
            navigator.clipboard.writeText(cmdEl.textContent.trim()).then(() => {
                const orig = cacheCopyBtn.textContent;
                cacheCopyBtn.textContent = 'Copied!';
                setTimeout(() => { cacheCopyBtn.textContent = orig; }, 2000);
            });
        });
    }

    // ── Mobile sidebar collapse ──────────────────────────────────────
    const sidebarHeaders = document.querySelectorAll('.sphinxsidebar h3, .sphinxsidebar h4');
    sidebarHeaders.forEach(header => {
        header.addEventListener('click', (e) => {
            if (window.innerWidth <= 768) {
                // Prevenir navegación si el enlace es solo un #
                if (e.target.tagName === 'A' && e.target.getAttribute('href') === '#') {
                    e.preventDefault();
                }
                header.classList.toggle('collapsed');
            }
        });
    });
})