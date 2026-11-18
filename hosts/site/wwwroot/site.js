// The site's one script: the theme switch and the menu. No framework and no other script.
// It only adds and removes classes the stylesheet already has (hosts/site/tests/StylesheetTests.cs reads the
// classList calls below), and it keeps what the present website keeps: localStorage key "theme", "light" or "dark".
(function () {
  'use strict';

  var root = document.documentElement;

  function saveTheme(theme) {
    try {
      localStorage.setItem('theme', theme);
    } catch (e) {
      /* no storage: the choice lasts for this page only */
    }
  }

  var themeButton = document.querySelector('[data-theme-toggle]');
  if (themeButton) {
    themeButton.addEventListener('click', function () {
      var dark = root.classList.toggle('dark');
      saveTheme(dark ? 'dark' : 'light');
    });
  }

  var panel = document.querySelector('[data-menu-panel]');
  var overlay = document.querySelector('[data-menu-overlay]');
  var menuButton = document.querySelector('[data-menu-toggle]');
  if (!panel || !overlay || !menuButton) {
    return;
  }

  var icons = menuButton.querySelectorAll('[data-menu-icon]');

  function setMenu(open) {
    if (open) {
      panel.classList.add('translate-x-0');
      panel.classList.remove('-translate-x-full');
      overlay.classList.remove('hidden');
      icons[0].classList.add('hidden');
      icons[1].classList.remove('hidden');
    } else {
      panel.classList.add('-translate-x-full');
      panel.classList.remove('translate-x-0');
      overlay.classList.add('hidden');
      icons[0].classList.remove('hidden');
      icons[1].classList.add('hidden');
    }
    menuButton.setAttribute('aria-expanded', open ? 'true' : 'false');
  }

  menuButton.addEventListener('click', function () {
    setMenu(panel.classList.contains('-translate-x-full'));
  });
  overlay.addEventListener('click', function () {
    setMenu(false);
  });
  panel.querySelector('[data-menu-close]').addEventListener('click', function () {
    setMenu(false);
  });
  panel.querySelectorAll('a').forEach(function (link) {
    link.addEventListener('click', function () {
      setMenu(false);
    });
  });

  // One category is open at a time, as on the present website.
  var categoryButtons = panel.querySelectorAll('[data-category-toggle]');

  function setCategory(button, open) {
    var list = panel.querySelector('[data-subcategories="' + button.getAttribute('data-category-toggle') + '"]');
    var arrow = button.querySelector('svg');
    if (open) {
      list.classList.remove('hidden');
      arrow.classList.add('rotate-180');
    } else {
      list.classList.add('hidden');
      arrow.classList.remove('rotate-180');
    }
    button.setAttribute('aria-label', open ? 'Collapse' : 'Expand');
  }

  categoryButtons.forEach(function (button) {
    button.addEventListener('click', function () {
      var open = button.getAttribute('aria-label') === 'Expand';
      categoryButtons.forEach(function (other) {
        setCategory(other, false);
      });
      setCategory(button, open);
    });
  });
})();
