// The site's one script: the theme switch, the menu, the publications page, the article list's filters, the Lectures page's language filter and load more, the home page's category cards and its search box. No framework and no other script.
// It only adds and removes classes the stylesheet already has (hosts/site/tests/StylesheetTests.cs reads the
// classList calls below, and the class lists the publications page and the article list hand over in their data- attributes), and it keeps what the present website keeps: localStorage key "theme", "light" or "dark".
// It holds no sentence a reader sees: the pages write every one (the publications page's count lines and summary labels, the article
// list's data-article-filters "texts") and the script picks one and fills in a name or a number.
(function () {
  'use strict';

  // The publications page's search: the text contains what was typed, in any case; an empty box matches everything.
  function matchesSearch(text, typed) {
    return text.toLowerCase().indexOf(typed.trim().toLowerCase()) !== -1;
  }

  // "{name}" or "{count}" in one of the page's words is where the value goes. Split and join, so a "$" in the value is only text.
  function fillIn(template, placeholder, value) {
    return template.split(placeholder).join(value);
  }

  function fill(template, name) {
    return fillIn(template, '{name}', name);
  }

  // The line above a tab's publications, for the number shown, in the words the page holds (words: none, one, many).
  function countLabel(count, words) {
    if (count === 0) {
      return words.none;
    }
    return count === 1 ? words.one : fillIn(words.many, '{count}', String(count));
  }

  // Runs one part of the page's setup. A part that throws is reported (never swallowed) and does not stop the parts after it.
  function attempt(name, setUp, report) {
    try {
      setUp();
    } catch (error) {
      report(name, error);
    }
  }

  function reportToConsole(name, error) {
    console.error('site.js: ' + name + ' failed', error);
  }

  // The home page's search: the trimmed text in q, and no q at all for an empty box, as the present website's search bar does.
  function searchTarget(action, typed) {
    var text = typed.trim();
    return text ? action + '?' + new URLSearchParams({ q: text }).toString() : action;
  }

  // The article list's filters. Which category and tag slugs a card holds, the tree, the counts and every sentence were decided
  // when the site was built (domains/content/site/ArticleFilters.cs); the functions here read the address, compare and fill in names.
  function has(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key);
  }

  // The present website's slugify (ArticlesList.tsx): the form every tag is compared in.
  function slugify(text) {
    return text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
  }

  // ?category= and ?tag=: the first value of each, decoded; empty when absent or empty.
  function readFilter(search) {
    var params = new URLSearchParams(search);
    return { category: params.get('category') || '', tag: params.get('tag') || '' };
  }

  // A card's categories and tags are "|a|b|" lists; a filter that is set must match, both when both are set.
  function matchesFilter(categories, tags, filter) {
    if (filter.category && (filter.category.indexOf('|') !== -1 || categories.indexOf('|' + filter.category + '|') === -1)) {
      return false;
    }
    return !filter.tag || tags.indexOf('|' + slugify(filter.tag) + '|') !== -1;
  }

  // The heading and the line under it. A tag wins over a category. An unknown category is headed by its slug.
  function headingFor(filter, data) {
    var texts = data.texts;
    if (filter.tag) {
      var name = has(data.tags, slugify(filter.tag)) ? data.tags[slugify(filter.tag)] : filter.tag;
      return { parent: '', title: fill(texts.tagTitle, name), description: fill(texts.tagDescription, name) };
    }
    if (!filter.category) {
      return { parent: '', title: texts.allArticles, description: texts.defaultDescription };
    }
    var category = has(data.categories, filter.category) ? data.categories[filter.category] : {};
    return {
      parent: category.parent || '',
      title: category.title || filter.category,
      description: category.description || texts.defaultDescription,
    };
  }

  // The chip beside "Filter by Category": the title of a category the panel lists, else the slug, as the present site does.
  function chipTitle(category, data) {
    return has(data.categories, category) && data.categories[category].chip ? data.categories[category].chip : category;
  }

  // The present website's box for a filter that finds no article.
  function noMatchText(filter, texts) {
    var title = texts.noneTitle;
    title += filter.category ? texts.noneInCategory : '';
    title += filter.tag ? fill(texts.noneWithTag, filter.tag) : '';
    var hint = filter.tag ? texts.hintTag : filter.category ? texts.hintCategory : '';
    return { title: title, hint: hint };
  }

  // A panel link is the current category, the parent of it (children is that parent's "|a|b|" list), or neither.
  function linkState(category, slug, children) {
    if (!category) {
      return 'none';
    }
    if (category === slug) {
      return 'current';
    }
    return category.indexOf('|') === -1 && children.indexOf('|' + category + '|') !== -1 ? 'ancestor' : 'none';
  }

  // The Lectures page: the cards to show for a language, the first count of them. groups is each card's data-language in page order;
  // language is '' for All or a group. total is how many cards match; show is the indexes of the first count of those.
  function lecturesToShow(groups, language, count) {
    var matching = [];
    groups.forEach(function (group, index) {
      if (language === '' || group === language) {
        matching.push(index);
      }
    });
    return { show: matching.slice(0, count), total: matching.length };
  }

  // Outside a browser (hosts/site/tests/js) the file only hands over the functions above.
  if (typeof document === 'undefined') {
    module.exports = {
      matchesSearch: matchesSearch,
      countLabel: countLabel,
      slugify: slugify,
      readFilter: readFilter,
      matchesFilter: matchesFilter,
      headingFor: headingFor,
      chipTitle: chipTitle,
      noMatchText: noMatchText,
      linkState: linkState,
      fill: fill,
      searchTarget: searchTarget,
      attempt: attempt,
      lecturesToShow: lecturesToShow,
    };
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

  function setUpTheme() {
    var themeButton = document.querySelector('[data-theme-toggle]');
    if (themeButton) {
      themeButton.addEventListener('click', function () {
        var dark = root.classList.toggle('dark');
        saveTheme(dark ? 'dark' : 'light');
      });
    }
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
    var countWords = {
      none: page.getAttribute('data-count-none'),
      one: page.getAttribute('data-count-one'),
      many: page.getAttribute('data-count-many'),
    };

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
        group.querySelector('[data-publications-count]').textContent = countLabel(shown, countWords);
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
      var moreLabel = button.textContent;
      var lessLabel = button.getAttribute('data-less-label');
      summary.classList.add('line-clamp-2');
      button.hidden = false;
      button.addEventListener('click', function () {
        var cut = summary.classList.toggle('line-clamp-2');
        button.textContent = cut ? moreLabel : lessLabel;
      });
    });

    tabList.hidden = false;
    searchBox.hidden = false;
    show();
  }

  function setUpPublicationsPage() {
    var publications = document.querySelector('[data-publications]');
    if (publications) {
      setUpPublications(publications);
    }
  }

  // The article list (domains/content/site/ArticleIndexPage.razor) is written whole. With ?category= or ?tag= this hides the
  // cards that do not match, words the heading, marks the active link and closes the panel; nothing is asked of the server.
  function setUpArticleFilters(page) {
    var filter = readFilter(location.search);
    var filtered = filter.category !== '' || filter.tag !== '';
    var data = JSON.parse(page.getAttribute('data-article-filters'));
    var shown = 0;

    page.querySelectorAll('[data-categories]').forEach(function (card) {
      var match = matchesFilter(card.getAttribute('data-categories'), card.getAttribute('data-tags'), filter);
      if (match) {
        card.classList.remove('hidden');
        shown += 1;
      } else {
        card.classList.add('hidden');
      }
    });

    if (filtered) {
      var heading = headingFor(filter, data);
      var title = page.querySelector('[data-filter-heading]');
      title.textContent = '';
      if (heading.parent) {
        var parent = document.createElement('span');
        parent.className = page.getAttribute('data-parent-class');
        parent.textContent = heading.parent + ' / ';
        title.appendChild(parent);
      }
      title.appendChild(document.createTextNode(heading.title));
      page.querySelector('[data-filter-description]').textContent = heading.description;
      page.querySelector('[data-filter-reset]').hidden = false;
    }

    var none = page.querySelector('[data-filter-none]');
    if (none && filtered && shown === 0) {
      var words = noMatchText(filter, data.texts);
      page.querySelector('[data-filter-none-title]').textContent = words.title;
      page.querySelector('[data-filter-none-hint]').textContent = words.hint;
      none.hidden = false;
    }

    var toggle = page.querySelector('[data-filter-toggle]');
    if (!toggle) {
      return;
    }

    var body = page.querySelector('[data-filter-body]');
    var arrow = page.querySelector('[data-filter-arrow]');
    function setPanel(open) {
      body.hidden = !open;
      arrow.classList.toggle('rotate-180', open);
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    }
    toggle.addEventListener('click', function () {
      setPanel(body.hidden);
    });
    setPanel(!filtered);

    if (filter.category) {
      var categoryChip = page.querySelector('[data-filter-chip="category"]');
      categoryChip.textContent = chipTitle(filter.category, data);
      categoryChip.hidden = false;
    }
    if (filter.tag) {
      var tagChip = page.querySelector('[data-filter-chip="tag"]');
      tagChip.textContent = fill(data.texts.tagChip, filter.tag);
      tagChip.hidden = false;
    }

    page.querySelectorAll('[data-filter-link]').forEach(function (link) {
      var state = link.hasAttribute('data-filter-all')
        ? (filtered ? 'none' : 'current')
        : linkState(filter.category, link.getAttribute('data-category'), link.getAttribute('data-children'));
      link.className = link.getAttribute('data-' + state + '-class');
    });

    // Each parent's subcategories are closed until its arrow opens them.
    page.querySelectorAll('[data-subcategory-toggle]').forEach(function (button) {
      var slug = button.getAttribute('data-subcategory-toggle');
      var list = page.querySelector('[data-subcategories="' + CSS.escape(slug) + '"]');
      var icon = button.querySelector('svg');
      var state = linkState(filter.category, slug, button.getAttribute('data-children'));
      button.className = button.getAttribute(state === 'none' ? 'data-none-class' : 'data-active-class');
      function setList(open) {
        list.hidden = !open;
        icon.classList.toggle('rotate-180', open);
        button.setAttribute('aria-label', open ? 'Collapse subcategories' : 'Expand subcategories');
      }
      button.addEventListener('click', function () {
        setList(list.hidden);
      });
      button.hidden = false;
      setList(false);
    });
  }

  // The home page's category cards (domains/content/site/HomePage.razor) write every card's subcategories open and their toggle
  // button hidden. Here: show the buttons and close the lists, as the present website starts; a button opens and closes its own
  // card, and a card is independent of the others.
  function setUpHomeCategories() {
    document.querySelectorAll('[data-category-card]').forEach(function (card) {
      var button = card.querySelector('[data-category-card-toggle]');
      var list = card.querySelector('[data-category-card-list]');
      if (!button || !list) {
        return;
      }
      var arrow = button.querySelector('svg');
      function setOpen(open) {
        list.hidden = !open;
        arrow.classList.toggle('rotate-180', open);
        button.setAttribute('aria-label', open ? 'Collapse' : 'Expand');
      }
      button.addEventListener('click', function () {
        setOpen(list.hidden);
      });
      button.hidden = false;
      setOpen(false);
    });
  }

  function setUpArticleFiltersPage() {
    var articleList = document.querySelector('[data-article-list]');
    if (articleList) {
      setUpArticleFilters(articleList);
    }
  }

  // The home page's search box is a plain GET form; here it sends the trimmed text, and nothing for an empty box.
  function setUpArticleSearch() {
    document.querySelectorAll('form[data-article-search]').forEach(function (form) {
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        location.assign(searchTarget(form.getAttribute('action'), form.querySelector('input[name="q"]').value));
      });
    });
  }

  // The Lectures page (domains/content/site/LecturesPage.razor) writes every card, the newest 24 shown, and its filter and "Load more" hidden.
  // Here: show the controls, then show and hide cards by language and count. The sentence and the button classes are the page's
  // (data-count-text, data-active-class, data-idle-class).
  function setUpLecturesPage() {
    var page = document.querySelector('main[data-lectures]');
    if (!page) {
      return;
    }

    var cards = page.querySelectorAll('[data-lecture]');
    var groups = Array.prototype.map.call(cards, function (card) {
      return card.getAttribute('data-language');
    });
    var buttons = page.querySelectorAll('[data-lecture-language]');
    var more = page.querySelector('[data-lecture-more]');
    var countText = page.getAttribute('data-count-text');
    var activeClass = page.getAttribute('data-active-class');
    var idleClass = page.getAttribute('data-idle-class');
    var pageSize = parseInt(page.getAttribute('data-page-size'), 10);
    var language = '';
    var count = pageSize;

    function swapClasses(button, remove, add) {
      remove.split(' ').forEach(function (name) {
        button.classList.remove(name);
      });
      add.split(' ').forEach(function (name) {
        button.classList.add(name);
      });
    }

    function render() {
      var result = lecturesToShow(groups, language, count);
      var visible = {};
      result.show.forEach(function (index) {
        visible[index] = true;
      });
      cards.forEach(function (card, index) {
        card.hidden = !visible[index];
      });
      var shown = fillIn(countText, '{shown}', String(result.show.length));
      page.querySelector('[data-lecture-count]').textContent = fillIn(shown, '{total}', String(result.total));
      more.hidden = result.show.length >= result.total;
      buttons.forEach(function (button) {
        var chosen = button.getAttribute('data-lecture-language') === language;
        swapClasses(button, chosen ? idleClass : activeClass, chosen ? activeClass : idleClass);
        button.setAttribute('aria-pressed', chosen ? 'true' : 'false');
      });
    }

    buttons.forEach(function (button) {
      button.addEventListener('click', function () {
        language = button.getAttribute('data-lecture-language');
        count = pageSize;
        render();
      });
    });
    more.querySelector('button').addEventListener('click', function () {
      count += pageSize;
      render();
    });

    page.querySelector('[data-lecture-filter]').hidden = false;
    render();
  }

  function setUpMenu() {
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
      var list = panel.querySelector('[data-subcategories="' + CSS.escape(button.getAttribute('data-category-toggle')) + '"]');
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
  }

  // The theme switch and the menu come first, and each page's own setup is guarded: one that throws is reported and the rest still run.
  attempt('theme switch', setUpTheme, reportToConsole);
  attempt('menu', setUpMenu, reportToConsole);
  attempt('publications page', setUpPublicationsPage, reportToConsole);
  attempt('home page category cards', setUpHomeCategories, reportToConsole);
  attempt('home page search', setUpArticleSearch, reportToConsole);
  attempt('article list filters', setUpArticleFiltersPage, reportToConsole);
  attempt('lectures page', setUpLecturesPage, reportToConsole);
})();
