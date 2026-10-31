/* iPhone-only glass navigation. The existing screens remain the source of truth. */
(function () {
  'use strict';
  function init() {
    if (!document.documentElement.classList.contains('cinegram-iphone')) return;
    if (document.getElementById('iphone-glass-nav')) return;
    var original = document.getElementById('bottom-nav');
    if (!original) return;
    var nav = document.createElement('nav');
    nav.id = 'iphone-glass-nav';
    nav.setAttribute('aria-label', 'Основная навигация');
    nav.innerHTML = '<div class="glass-tabs">' +
      '<button type="button" class="glass-tab" data-glass-screen="home" aria-label="Главная"><svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10 12 3l9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z"/></svg><span>Главная</span></button>' +
      '<button type="button" class="glass-tab" data-glass-screen="collections" aria-label="Подборки"><svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="7" height="7" rx="1.5"/><rect x="14" y="4" width="7" height="7" rx="1.5"/><rect x="3" y="15" width="7" height="7" rx="1.5"/><rect x="14" y="15" width="7" height="7" rx="1.5"/></svg><span>Подборки</span></button>' +
      '<button type="button" class="glass-tab" data-glass-screen="profile" aria-label="Профиль"><svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg><span>Профиль</span></button>' +
      '</div><button type="button" class="glass-search" aria-label="Поиск"><svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/></svg></button>';
    document.body.appendChild(nav);

    var backdrop = document.createElement('div');
    backdrop.className = 'glass-sheet-backdrop';
    backdrop.hidden = true;
    backdrop.innerHTML = '<section class="glass-sheet" role="dialog" aria-modal="true" aria-labelledby="glass-sheet-title">' +
      '<header class="glass-sheet-header"><h2 class="glass-sheet-title" id="glass-sheet-title"></h2>' +
      '<button type="button" class="glass-sheet-close" aria-label="Закрыть">×</button></header>' +
      '<div class="glass-sheet-items"></div></section>';
    document.body.appendChild(backdrop);
    var title = backdrop.querySelector('.glass-sheet-title');
    var items = backdrop.querySelector('.glass-sheet-items');
    var origin = null;
    var openScreen = null;

    function originalButton(screen) { return original.querySelector('.nav-btn[data-screen="' + screen + '"]'); }
    function goHome() {
      var button = originalButton('home');
      if (button) button.click();
    }
    function closeSheet(restoreFocus) {
      backdrop.hidden = true;
      openScreen = null;
      sync();
      if (restoreFocus && origin && typeof origin.focus === 'function') origin.focus();
    }
    function addItem(label, action, selected) {
      var item = document.createElement('button');
      item.type = 'button';
      item.className = 'glass-sheet-item' + (selected ? ' active' : '');
      item.textContent = label;
      item.addEventListener('click', function () { closeSheet(false); action(); });
      items.appendChild(item);
    }
    function openSheet(screen, button) {
      if (!backdrop.hidden && openScreen === screen) { closeSheet(true); return; }
      origin = button;
      openScreen = screen;
      items.replaceChildren();
      if (screen === 'profile') {
        title.textContent = 'Профиль';
        [['watchlist', 'Мой список'], ['history', 'История'], ['settings', 'Настройки']].forEach(function (entry) {
          var originalItem = originalButton(entry[0]);
          if (originalItem) addItem(entry[1], function () { originalItem.click(); }, originalItem.classList.contains('active'));
        });
      } else {
        title.textContent = 'Подборки';
        /* Re-rendered when entering home, so capture identifiers instead of stale nodes. */
        var choices = document.querySelectorAll('#genres-row button.genre-chip, #services-row button, #services-row .service-card');
        Array.prototype.forEach.call(choices, function (choice, index) {
          var label = (choice.textContent || '').trim();
          if (!label) return;
          var genreId = choice.dataset.genreId;
          var sort = choice.dataset.sort;
          var service = choice.dataset.service;
          var wasService = !!choice.closest('#services-row');
          addItem(label, function () {
            goHome();
            var selector = wasService ? '#services-row button, #services-row .service-card' : '#genres-row button.genre-chip';
            var matching = Array.prototype.slice.call(document.querySelectorAll(selector));
            var target = matching.find(function (candidate) {
              return genreId ? candidate.dataset.genreId === genreId : sort ? candidate.dataset.sort === sort : service ? candidate.dataset.service === service : (candidate.textContent || '').trim() === label;
            });
            if (!target && wasService) target = matching[index];
            if (target) target.click();
          }, choice.classList.contains('active'));
        });
        if (!items.children.length) addItem('Открыть каталог', goHome, false);
      }
      backdrop.hidden = false;
      sync();
      var first = items.querySelector('button');
      if (first) first.focus();
    }
    function sync() {
      var hidden = original.style.display === 'none';
      nav.hidden = hidden;
      if (hidden && !backdrop.hidden) closeSheet(false);
      var active = original.querySelector('.nav-btn.active');
      var activeScreen = active && active.dataset.screen;
      var selected = openScreen || (activeScreen === 'home' || !activeScreen ? 'home' : 'profile');
      nav.querySelectorAll('.glass-tab').forEach(function (button) {
        var on = button.dataset.glassScreen === selected;
        button.classList.toggle('active', on);
        if (on) button.setAttribute('aria-current', 'page'); else button.removeAttribute('aria-current');
      });
    }
    nav.querySelector('[data-glass-screen="home"]').addEventListener('click', function () { closeSheet(false); goHome(); });
    ['collections', 'profile'].forEach(function (screen) {
      var button = nav.querySelector('[data-glass-screen="' + screen + '"]');
      button.addEventListener('click', function () { openSheet(screen, button); });
    });
    nav.querySelector('.glass-search').addEventListener('click', function () {
      closeSheet(false);
      if (!document.querySelector('#screen-home.active')) goHome();
      var search = document.getElementById('btn-search-open');
      if (search) search.click();
    });
    backdrop.querySelector('.glass-sheet-close').addEventListener('click', function () { closeSheet(true); });
    backdrop.addEventListener('click', function (event) { if (event.target === backdrop) closeSheet(true); });
    document.addEventListener('keydown', function (event) { if (event.key === 'Escape' && !backdrop.hidden) { event.preventDefault(); closeSheet(true); } });
    new MutationObserver(sync).observe(original, { attributes: true, attributeFilter: ['style', 'class'], subtree: true });
    sync();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
