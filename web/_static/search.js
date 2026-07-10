// ─── LumiROM Simple Search ───────────────────────────────────────────────────

const SEARCH_INDEX = [
    {
        title: "Introduction",
        url: "index.html",
        content: "Welcome to the documentation for LumiROM - a custom ROM designed to bring One UI and Galaxy AI to low-end Samsung MediaTek devices. What does LumiROM do? How it works Firmware Download OTA Merging & Extraction Optimizations & Tweaks EROFS Packaging Universal compilation Community."
    },
    {
        title: "Supported Devices",
        url: "devices.html",
        content: "LumiROM is specifically designed and tested for popular low-end Samsung Galaxy models powered by MediaTek chipsets. Fingerprint on Display (FOD) Devices Galaxy A32 4G SM-A325F SM-A325M Galaxy M32 SM-M325F Side Fingerprint Devices Galaxy A22 SM-A225F Galaxy A22 5G SM-A226B Galaxy F22 SM-E225F Base Information."
    },
    {
        title: "Features",
        url: "features.html",
        content: "A complete suite of system optimizations, advanced security modifications, and Galaxy AI magic. Heavy Debloat Deodexed ROM EROFS Filesystem Battery & CPU Tweaks High-End Animations VoLTE Fix Call Assist Writing Assist Note Assist Transcript Assist Browsing Assist Photo Assist Knox Patches Secure Folder Samsung Health SmartThings Knox Guard Disabled Bypass Flag Secure Signature Verification Screenshot Anywhere Native Screen Recorder Bluetooth Recording."
    },
    {
        title: "Build Methods",
        url: "build.html",
        content: "Select your compilation method: automate through GitHub in the cloud, or compile locally on your Linux machine. GitHub Actions (Cloud) Fork the Repository Run the Workflow Configure Device Parameters Hugging Face Upload Local Build Clone the Repository Configure Build Variables Execute the Script Manage Firmware Cache."
    },
    {
        title: "Changelogs",
        url: "changelogs.html",
        content: "Every version, every fix, every feature. Browse the complete release history of LumiROM. Version history updates fixes bugs features."
    },
    {
        title: "License",
        url: "license.html",
        content: "LumiROM is open source software. The scripts, tooling and build system are distributed under the MIT License. Third-party Tools samloader Apktool erofs-utils Magisk."
    }
];

document.addEventListener('DOMContentLoaded', () => {
    const params = new URLSearchParams(window.location.search);
    const query = params.get('q');
    
    const searchInput = document.getElementById('search-input');
    const resultsContainer = document.getElementById('search-results');
    
    if (!resultsContainer) return;

    if (query) {
        if (searchInput) searchInput.value = query;
        performSearch(query.toLowerCase());
    } else {
        resultsContainer.innerHTML = '<p>Please enter a search term above.</p>';
    }

    function performSearch(q) {
        if (!q.trim()) {
            resultsContainer.innerHTML = '<p>Please enter a search term above.</p>';
            return;
        }

        const results = SEARCH_INDEX.filter(item => 
            item.title.toLowerCase().includes(q) || 
            item.content.toLowerCase().includes(q)
        );

        if (results.length === 0) {
            resultsContainer.innerHTML = '<p>No results found for <strong>' + escapeHtml(q) + '</strong>.</p>';
            return;
        }

        let html = '<h2>Search Results</h2><ul class="search-results-list">';
        results.forEach(result => {
            html += `
                <li>
                    <h3><a href="${result.url}">${result.title}</a></h3>
                    <p>${highlight(result.content, q)}</p>
                </li>
            `;
        });
        html += '</ul>';
        resultsContainer.innerHTML = html;
    }

    function escapeHtml(str) {
        return str.replace(/[&<>'"]/g, 
            tag => ({
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                "'": '&#39;',
                '"': '&quot;'
            }[tag] || tag)
        );
    }

    function highlight(content, query) {
        const lowerContent = content.toLowerCase();
        const index = lowerContent.indexOf(query);
        if (index === -1) return content.substring(0, 150) + '...';
        
        const start = Math.max(0, index - 50);
        const end = Math.min(content.length, index + query.length + 50);
        
        let snippet = content.substring(start, end);
        if (start > 0) snippet = '...' + snippet;
        if (end < content.length) snippet = snippet + '...';
        
        const regex = new RegExp(`(${query})`, 'gi');
        return snippet.replace(regex, '<strong>$1</strong>');
    }
});
