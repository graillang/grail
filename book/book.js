(() => {
  const $ = selector => document.querySelector(selector);
  const escape = text => text.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  let savedTheme;
  try { savedTheme = localStorage.getItem('grail-book-theme'); } catch {}
  document.documentElement.dataset.theme = savedTheme || 'light';
  $('#theme-toggle').addEventListener('click', () => {
    const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = theme;
    try { localStorage.setItem('grail-book-theme', theme); } catch {}
  });
  const toggleMenu = open => {
    $('#sidebar').classList.toggle('open', open);
    $('#menu-toggle').setAttribute('aria-expanded', String(open));
  };
  $('#menu-toggle').addEventListener('click', () => toggleMenu(!$('#sidebar').classList.contains('open')));
  document.addEventListener('click', event => {
    if (!event.target.closest('#sidebar, #menu-toggle')) toggleMenu(false);
  });
  document.querySelectorAll('pre').forEach(pre => {
    const code = pre.querySelector('code');
    const raw = code.textContent;
    const clipboardText = code.classList.contains('language-sh') ? raw.replace(/^\$ /gm, '') : raw;
    if (code.classList.contains('language-grl') || code.classList.contains('language-rust')) {
      const tokens = /(\/\/[^\n]*|"(?:\\.|[^"\\])*"|\b\d+\b|\b(?:module|use|pub|fn|let|if|else|while|for|in|break|continue|return|struct|enum|match|type|num|unit|bytes|string|read|mut|vec|ref|ref_mut|assert|drop|main|mut|u64|u8|usize|String|Vec|Option|Result|Some|None|Ok|Err|true|false)\b)/g;
      let html = '', end = 0;
      for (const match of raw.matchAll(tokens)) {
        html += escape(raw.slice(end, match.index));
        const value = match[0];
        const kind = value.startsWith('//') ? 'comment' : value.startsWith('"') ? 'string' : /^\d/.test(value) ? 'number' : 'keyword';
        html += value === "let" && code.classList.contains("language-grl") ? escape(value) : `<span class="tok-${kind}">${escape(value)}</span>`;
        end = match.index + value.length;
      }
      code.innerHTML = html + escape(raw.slice(end));
    }
    const button = document.createElement('button');
    button.className = 'copy'; button.textContent = 'Copy'; button.setAttribute('aria-label', 'Copy code');
    button.addEventListener('click', async () => {
      try {
        if (navigator.clipboard?.writeText) await navigator.clipboard.writeText(clipboardText);
        else {
          const area = document.createElement('textarea'); area.value = clipboardText;
          area.style.position = 'fixed'; area.style.opacity = '0'; document.body.append(area); area.select();
          const copied = document.execCommand('copy'); area.remove();
          if (!copied) throw new Error('Clipboard unavailable');
        }
        button.textContent = 'Copied';
      } catch { button.textContent = 'Select to copy'; }
      setTimeout(() => { button.textContent = 'Copy'; }, 1800);
    });
    pre.append(button);
  });
  const comparisons = [...document.querySelectorAll('.rust-column')];
  let savedRust;try {savedRust=localStorage.getItem('grail-book-rust');} catch {}
  if(savedRust==='hidden') comparisons.forEach(panel=>{panel.open=false;});
  const rustToggle = $('#rust-toggle');
  rustToggle.hidden = comparisons.length === 0;
  const updateRustToggle = () => { rustToggle.textContent = comparisons.every(panel => panel.open) ? 'Hide Rust' : 'Show Rust'; };
  rustToggle.addEventListener('click', () => { const open = !comparisons.every(panel => panel.open); comparisons.forEach(panel => { panel.open = open; }); try {localStorage.setItem('grail-book-rust',open?'shown':'hidden');} catch {} updateRustToggle(); });
  updateRustToggle();

  const search = $('#search'), results = $('#search-results'), status = $('#search-status');
  search.addEventListener('input', () => {
    const query = search.value.trim().toLowerCase();
    document.body.classList.toggle('searching', Boolean(query));
    results.hidden = !query; results.replaceChildren(); status.textContent = '';
    if (!query) return;
    const words = query.split(/\s+/);
    const matches = (window.grailBookSearch || []).filter(page => words.every(word => `${page.title} ${page.text}`.toLowerCase().includes(word)));
    status.textContent = `${matches.length} chapter${matches.length === 1 ? '' : 's'} found`;
    for (const page of matches) {
      const at = page.text.toLowerCase().indexOf(words[0]);
      const snippet = page.text.slice(Math.max(0, at - 35), Math.max(0, at - 35) + 140).replace(/\s+/g, ' ');
      const item = document.createElement('li'), link = document.createElement('a'), small = document.createElement('small');
      link.href = page.url; link.textContent = page.title; small.textContent = `…${snippet}…`;
      link.append(small); item.append(link); results.append(item);
    }
  });
  document.addEventListener('keydown', event => {
    const typing = event.target.closest('input, textarea, [contenteditable]');
    if ((!typing && event.key === '/') || ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k')) {
      event.preventDefault(); toggleMenu(true); search.focus();
    }
    if (event.key === 'Escape') { search.value = ''; search.dispatchEvent(new Event('input')); search.blur(); toggleMenu(false); }
    if (!typing && !event.ctrlKey && !event.metaKey && !event.altKey && !event.shiftKey) {
      const link = event.key === 'ArrowLeft' ? $('.previous') : event.key === 'ArrowRight' ? $('.next') : null;
      if (link && !event.target.closest('button, a')) location.href = link.href;
    }
  });
})();
(() => {
  // Charts: a button in each chart's corner shows that chart full screen; the button (or Esc) leaves.
  // Where a page cannot go full screen (an iPhone), there is no button.
  const supported = document.fullscreenEnabled || document.webkitFullscreenEnabled;
  const charts = document.querySelectorAll('figure.perf-chart');
  if (!supported || charts.length === 0) return;
  const current = () => document.fullscreenElement || document.webkitFullscreenElement;
  const label = (button, on) => {
    button.textContent = on ? '✕' : '⛶';
    button.title = on ? 'Leave full screen (Esc)' : 'Full screen';
    button.setAttribute('aria-label', on ? 'Leave full screen' : 'Show this chart full screen');
  };
  charts.forEach(figure => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'perf-fullscreen';
    label(button, false);
    button.addEventListener('click', () => {
      if (current() === figure) (document.exitFullscreen || document.webkitExitFullscreen).call(document);
      else (figure.requestFullscreen || figure.webkitRequestFullscreen).call(figure);
    });
    figure.prepend(button);
  });
  const sync = () => charts.forEach(figure => label(figure.querySelector('.perf-fullscreen'), current() === figure));
  document.addEventListener('fullscreenchange', sync);
  document.addEventListener('webkitfullscreenchange', sync);
})();
