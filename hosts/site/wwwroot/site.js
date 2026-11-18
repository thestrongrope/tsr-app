// The site's one script: the theme switch, the publications page and the menu. No framework and no other script.
// It only adds and removes classes the stylesheet already has (hosts/site/tests/StylesheetTests.cs reads the
// classList calls below, and the class lists the publications page hands over in its data- attributes), and it keeps what the present website keeps: localStorage key "theme", "light" or "dark".
(function () {
  'use strict';

  // The publications page's search: the text contains what was typed, in any case; an empty box matches everything.
  function matchesSearch(text, typed) {
    return text.toLowerCase().indexOf(typed.trim().toLowerCase()) !== -1;
  }

  // The line above a tab's publications, for the number shown.
  function countLabel(count) {
    if (count === 0) {
      return 'No matches';
    }
    return count === 1 ? '1 publication available' : count + ' publications available';
  }

  // Outside a browser (hosts/site/tests/js) the file only hands over the two functions above.
  if (typeof document === 'undefined') {
    module.exports = { matchesSearch: matchesSearch, countLabel: countLabel };
    return;
  }

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

  // The publications page (domains/content/site/PublicationsPage.razor) writes every language's group and hides what
  // needs this script. Here: show those, then one group at a time, filtered by the search box. Which publications there
  // are, their groups and their order were decided when the site was built.
  function setUpPublications(page) {
    var tabList = page.querySelector('[role="tablist"]');
    var tabs = page.querySelectorAll('[data-publications-tab]');
    var panels = page.querySelectorAll('[data-publications-panel]');
    var searchBox = page.querySelector('[data-publications-search]');
    var search = searchBox.querySelector('input');
    var active = tabs[0].getAttribute('data-publications-tab');

    function show() {
      tabs.forEach(function (tab) {
        var chosen = tab.getAttribute('data-publications-tab') === active;
        tab.className = tabList.getAttribute(chosen ? 'data-active-class' : 'data-inactive-class');
        tab.lastElementChild.className = tabList.getAttribute(chosen ? 'data-count-active-class' : 'data-count-inactive-class');
        tab.setAttribute('aria-selected', chosen ? 'true' : 'false');
      });
      panels.forEach(function (group) {
        group.hidden = group.getAttribute('data-publications-panel') !== active;
        var shown = 0;
        group.querySelectorAll('[data-search-text]').forEach(function (card) {
          card.hidden = !matchesSearch(card.getAttribute('data-search-text'), search.value);
          shown += card.hidden ? 0 : 1;
        });
        group.querySelector('[data-publications-count]').textContent = countLabel(shown);
      });
    }

    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        active = tab.getAttribute('data-publications-tab');
        show();
      });
    });
    search.addEventListener('input', show);

    // A summary is cut to two lines until "more" opens it.
    page.querySelectorAll('[data-summary-toggle]').forEach(function (button) {
      var summary = button.parentNode.querySelector('[data-summary]');
      summary.classList.add('line-clamp-2');
      button.hidden = false;
      button.addEventListener('click', function () {
        var cut = summary.classList.toggle('line-clamp-2');
        button.textContent = cut ? 'more' : 'show less';
      });
    });

    tabList.hidden = false;
    searchBox.hidden = false;
    show();
  }

  var publications = document.querySelector('[data-publications]');
  if (publications) {
    setUpPublications(publications);
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
