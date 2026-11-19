// The Self-reflection pages' script (/self-reflection/en, /ur, /gu), loaded by those pages only. No framework and no other script.
// The reader's answers stay on the device: they are read from and written to localStorage under the present website's key
// "tsr-self-reflection", in the present website's shape, and nothing is sent anywhere.
// The page (domains/content/site/SelfReflectionPage.razor) writes every sentence, every class set (data-on-class and data-off-class) and every
// name; this file scores, saves and shows or hides what the page wrote hidden. Section 2 is scored by the option's position, never by its text.
(function () {
  'use strict';

  var STORAGE_KEY = 'tsr-self-reflection';
  var SECTION_MAX = [6, 5, 5, 3];
  var TOTAL_MAX = 19;
  var LEVELS = ['weak', 'inconsistent', 'strong'];

  // The form as the script holds it: section 2 as positions (choiceWords keeps the words an answer was stored in, until the reader changes
  // that answer), the rest as the present site stores it.
  function emptyForm() {
    return {
      checks: [null, null, null, null, null, null],
      reflection1: '',
      choices: [null, null, null, null, null],
      choiceWords: [null, null, null, null, null],
      reflection2: '',
      answers3: ['', '', '', ''],
      traits: [null, null, null, null, null],
      reflection4: '',
      choice: null,
      other: '',
      plan: '',
      covenant: '',
    };
  }

  // The scores of sections 1, 2, 4 and 5 (section 3 and 6 are not scored), by the present website's rules.
  function sectionScores(form) {
    var s1 = 0;
    for (var i = 0; i < 3; i++) {
      if (form.checks[i] === true) s1 += 1;
    }
    for (var j = 3; j < 6; j++) {
      if (form.checks[j] === false) s1 += 1;
    }

    var c = form.choices;
    var s2 = 0;
    if (c[0] === 1) s2 += 1;
    if (c[1] === 1) s2 += 1;
    if (c[2] !== null) s2 += 1;
    if (c[3] === 0) s2 += 1;
    if (c[4] === 0) s2 += 1;

    var s4 = 0;
    form.traits.forEach(function (trait) {
      if (trait === 'strong') s4 += 1;
      else if (trait === 'inconsistent') s4 += 0.5;
    });

    var s5 = 0;
    var plan = form.plan.trim().length;
    if (form.choice !== null && (form.choice < 5 || form.other.trim().length > 0)) s5 += 1;
    if (plan > 30) s5 += 2;
    else if (plan > 0) s5 += 1;
    return [s1, s2, s4, Math.min(s5, 3)];
  }

  // 0: 15 and over, 1: 11 up to 15, 2: 6 up to 11, 3: below 6.
  function rangeFor(total) {
    if (total >= 15) return 0;
    if (total >= 11) return 1;
    if (total >= 6) return 2;
    return 3;
  }

  // The section with the lowest share of its own maximum; a tie keeps the first.
  function weakestOf(scores) {
    var weakest = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] / SECTION_MAX[i] < scores[weakest] / SECTION_MAX[weakest]) weakest = i;
    }
    return weakest;
  }

  function progressPercent(total) {
    return Math.round((total / TOTAL_MAX) * 100);
  }

  function summarize(form) {
    var scores = sectionScores(form);
    var total = scores[0] + scores[1] + scores[2] + scores[3];
    return {
      scores: scores,
      total: total,
      totalText: total.toFixed(1),
      range: rangeFor(total),
      weakest: weakestOf(scores),
      percent: progressPercent(total),
    };
  }

  function isOneOf(value, allowed) {
    return allowed.indexOf(value) !== -1;
  }

  // Each reader of a stored field returns undefined for a value of the wrong type, and the default for a missing one.
  function readList(value, length, accept) {
    if (value === undefined || value === null) return null;
    if (!Array.isArray(value) || value.length !== length) return undefined;
    return value.every(accept) ? value : undefined;
  }

  function isText(value) {
    return typeof value === 'string';
  }

  // A saved answer of section 2 is the option's words in the language it was given in: its position is where those words stand in
  // any of the languages' lists for that question; words that stand nowhere are no answer.
  function positionOf(question, words, optionLists) {
    if (words === null) return null;
    for (var i = 0; i < optionLists.length; i++) {
      var at = optionLists[i][question].indexOf(words);
      if (at !== -1) return at;
    }
    return null;
  }

  // Stored text to a form. Anything that is not a form of the present site's shape gives the empty form; it never throws.
  // onDiscard, when given, is called with a reason (never with an answer) when stored text is thrown away; no stored text is not a discard.
  function parseStored(text, optionLists, onDiscard) {
    var discard = function (reason) {
      if (onDiscard) onDiscard(reason);
      return emptyForm();
    };
    if (text === null || text === undefined) return emptyForm();
    var data;
    try {
      data = JSON.parse(text);
    } catch (e) {
      return discard('the stored answers are not JSON');
    }
    if (data === null || typeof data !== 'object' || Array.isArray(data)) return discard('the stored answers are not a form');

    var form = emptyForm();
    var checks = readList(data.section1Checks, 6, function (v) { return v === null || typeof v === 'boolean'; });
    var choices = readList(data.section2Choices, 5, function (v) { return v === null || isText(v); });
    var answers3 = readList(data.section3Answers, 4, isText);
    var traits = readList(data.section4Traits, 5, function (v) { return v === null || isOneOf(v, LEVELS); });
    var texts = {
      reflection1: data.section1Reflection,
      reflection2: data.section2Reflection,
      reflection4: data.section4Reflection,
      other: data.section5Other,
      plan: data.section5Plan,
      covenant: data.covenant,
    };
    var choice = data.section5Choice;
    var textsOk = Object.keys(texts).every(function (key) { return texts[key] === undefined || texts[key] === null || isText(texts[key]); });
    var choiceOk = choice === undefined || choice === null || (Number.isInteger(choice) && choice >= 0 && choice <= 5);
    if (checks === undefined || choices === undefined || answers3 === undefined || traits === undefined || !textsOk || !choiceOk) {
      return discard('the stored answers have a field of the wrong type or length');
    }

    if (checks) form.checks = checks;
    if (choices) {
      form.choices = choices.map(function (words, q) { return positionOf(q, words, optionLists); });
      form.choiceWords = choices.map(function (words, q) { return form.choices[q] === null ? null : words; });
    }
    if (answers3) form.answers3 = answers3;
    if (traits) form.traits = traits;
    Object.keys(texts).forEach(function (key) {
      if (isText(texts[key])) form[key] = texts[key];
    });
    form.choice = choice === undefined ? null : choice;
    return form;
  }

  // The words of a section 2 answer: the words it was stored in while the reader has not changed it, else this page's language's words.
  function wordsOf(form, q, pageOptions) {
    if (form.choices[q] === null) return null;
    return form.choiceWords[q] !== null ? form.choiceWords[q] : pageOptions[q][form.choices[q]];
  }

  // The reader chooses (or, choosing it again, clears) an option of question q: the answer is theirs now, in this page's words.
  function chooseOption(form, q, position) {
    form.choices[q] = form.choices[q] === position ? null : position;
    form.choiceWords[q] = null;
  }

  // The form as the present site stores it: section 2 as words (see wordsOf).
  function toStored(form, optionLists, now) {
    return {
      section1Checks: form.checks,
      section1Reflection: form.reflection1,
      section2Choices: form.choices.map(function (at, q) { return wordsOf(form, q, optionLists); }),
      section2Reflection: form.reflection2,
      section3Answers: form.answers3,
      section4Traits: form.traits,
      section4Reflection: form.reflection4,
      section5Choice: form.choice,
      section5Other: form.other,
      section5Plan: form.plan,
      covenant: form.covenant,
      lastUpdated: now,
    };
  }

  // The three functions below take a function that returns the storage, and call it inside their try: a browser with site data blocked
  // throws when window.localStorage is touched at all. Storage that cannot be read starts the form empty.
  function loadForm(getStorage, optionLists, onDiscard) {
    var text;
    try {
      text = getStorage().getItem(STORAGE_KEY);
    } catch (e) {
      if (onDiscard) onDiscard('the browser would not give the stored answers');
      return emptyForm();
    }
    return parseStored(text, optionLists, onDiscard);
  }

  // The page's new state when another page changes the browser's storage (the "storage" event: key and newValue; key null means the
  // whole storage was cleared); null when the change is not to this page's key. A removed value is an empty form, never the old answers.
  function formAfterStorageEvent(event, optionLists) {
    if (event.key !== null && event.key !== STORAGE_KEY) return null;
    return parseStored(event.key === null ? null : event.newValue, optionLists);
  }

  // True when the form was written; false when the browser refused (full, blocked): the form still works for this visit.
  function saveForm(getStorage, form, pageOptions, now) {
    try {
      getStorage().setItem(STORAGE_KEY, JSON.stringify(toStored(form, pageOptions, now)));
      return true;
    } catch (e) {
      return false;
    }
  }

  function clearForm(getStorage) {
    try {
      getStorage().removeItem(STORAGE_KEY);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Outside a browser (hosts/site/tests/js) the file only hands over the functions above.
  if (typeof document === 'undefined') {
    module.exports = {
      STORAGE_KEY: STORAGE_KEY,
      emptyForm: emptyForm,
      sectionScores: sectionScores,
      rangeFor: rangeFor,
      weakestOf: weakestOf,
      progressPercent: progressPercent,
      summarize: summarize,
      parseStored: parseStored,
      toStored: toStored,
      chooseOption: chooseOption,
      formAfterStorageEvent: formAfterStorageEvent,
      loadForm: loadForm,
      saveForm: saveForm,
      clearForm: clearForm,
    };
    return;
  }

  var page = document.querySelector('[data-self-reflection]');
  if (!page) return;

  var optionLists = JSON.parse(page.getAttribute('data-options-all'));
  var pageOptions = optionLists[Number(page.getAttribute('data-options-current'))];
  var confirmText = page.getAttribute('data-confirm-reset');
  function storage() {
    return window.localStorage;
  }

  function warn(reason) {
    console.warn('self-reflection.js: ' + reason + '; the form starts empty');
  }

  var form = loadForm(storage, optionLists, warn);

  function all(selector) {
    return page.querySelectorAll(selector);
  }

  function each(selector, action) {
    all(selector).forEach(action);
  }

  function classes(element, attribute) {
    return element.getAttribute(attribute).split(' ').filter(Boolean);
  }

  // An element with data-on-class and data-off-class shows one set or the other; the page wrote both.
  function setOn(element, on) {
    var remove = classes(element, on ? 'data-off-class' : 'data-on-class');
    var add = classes(element, on ? 'data-on-class' : 'data-off-class');
    remove.forEach(function (name) { element.classList.remove(name); });
    add.forEach(function (name) { element.classList.add(name); });
    if (element.tagName === 'BUTTON') {
      element.setAttribute('aria-pressed', on ? 'true' : 'false');
    }
  }

  function toggleIn(list, index, value) {
    list[index] = list[index] === value ? null : value;
  }

  function showOnly(selector, index) {
    each(selector, function (element) {
      element.hidden = Number(element.getAttribute(selector.slice(1, -1))) !== index;
    });
  }

  function showSelections() {
    each('[data-sr-check]', function (button) {
      var wanted = button.getAttribute('data-sr-value') === 'yes';
      setOn(button, form.checks[Number(button.getAttribute('data-sr-check'))] === wanted);
    });
    each('[data-sr-option]', function (button) {
      var q = Number(button.getAttribute('data-sr-option'));
      setOn(button, form.choices[q] === Number(button.getAttribute('data-sr-position')));
    });
    each('[data-sr-trait]', function (button) {
      setOn(button, form.traits[Number(button.getAttribute('data-sr-trait'))] === button.getAttribute('data-sr-level'));
    });
    each('[data-sr-row]', function (row) {
      setOn(row, form.choice === Number(row.getAttribute('data-sr-row')));
    });
    each('[data-sr-radio]', function (radio) {
      setOn(radio, form.choice === Number(radio.getAttribute('data-sr-radio')));
    });
    each('[data-sr-dot]', function (dot) {
      dot.hidden = form.choice !== Number(dot.getAttribute('data-sr-dot'));
    });
  }

  function showScores() {
    var result = summarize(form);
    each('[data-sr-badge]', function (badge) {
      badge.querySelector('[data-sr-badge-value]').textContent = String(result.scores[Number(badge.getAttribute('data-sr-badge'))]);
    });
    each('[data-sr-total]', function (element) { element.textContent = result.totalText; });
    each('[data-sr-percent]', function (element) { element.textContent = result.percent + '%'; });
    each('[data-sr-bar]', function (element) { element.style.width = result.percent + '%'; });
    each('[data-sr-range]', function (element) { setOn(element, Number(element.getAttribute('data-sr-range')) === result.range); });
    showOnly('[data-sr-tier]', result.range);
    showOnly('[data-sr-weakest]', result.weakest);
    showOnly('[data-sr-focus]', result.weakest);
    each('[data-sr-weakest-score]', function (element) {
      element.textContent = String(result.scores[result.weakest]);
    });
  }

  function refresh() {
    showSelections();
    showScores();
  }

  function fieldValue(name, index) {
    return index === null ? form[name] : form[name][index];
  }

  function fillFields() {
    each('[data-sr-field]', function (field) {
      var index = field.hasAttribute('data-sr-index') ? Number(field.getAttribute('data-sr-index')) : null;
      field.value = fieldValue(field.getAttribute('data-sr-field'), index);
    });
  }

  function save() {
    if (!saveForm(storage, form, pageOptions, new Date().toISOString())) {
      console.error('self-reflection.js: the browser would not keep the answers; they last for this visit only');
    }
  }

  function changed() {
    refresh();
    save();
  }

  function onClick(event) {
    var button = event.target.closest('button');
    if (!button || !page.contains(button)) return;
    if (button.hasAttribute('data-sr-check')) {
      toggleIn(form.checks, Number(button.getAttribute('data-sr-check')), button.getAttribute('data-sr-value') === 'yes');
    } else if (button.hasAttribute('data-sr-option')) {
      chooseOption(form, Number(button.getAttribute('data-sr-option')), Number(button.getAttribute('data-sr-position')));
    } else if (button.hasAttribute('data-sr-trait')) {
      toggleIn(form.traits, Number(button.getAttribute('data-sr-trait')), button.getAttribute('data-sr-level'));
    } else if (button.hasAttribute('data-sr-step')) {
      var step = Number(button.getAttribute('data-sr-step'));
      form.choice = form.choice === step ? null : step;
    } else {
      return;
    }
    changed();
  }

  function onInput(event) {
    var field = event.target;
    if (!field.hasAttribute || !field.hasAttribute('data-sr-field')) return;
    var name = field.getAttribute('data-sr-field');
    if (field.hasAttribute('data-sr-index')) {
      form[name][Number(field.getAttribute('data-sr-index'))] = field.value;
    } else {
      form[name] = field.value;
    }
    changed();
  }

  // Typing in "Other" chooses it, as the present site does.
  function onFocus(event) {
    if (event.target.hasAttribute && event.target.hasAttribute('data-sr-field') && event.target.getAttribute('data-sr-field') === 'other' && form.choice !== 5) {
      form.choice = 5;
      changed();
    }
  }

  function onReset() {
    if (!window.confirm(confirmText)) return;
    form = emptyForm();
    if (!clearForm(storage)) {
      console.error('self-reflection.js: the browser would not clear the saved answers');
    }
    fillFields();
    refresh();
  }

  // Another copy of the page (a tab, or this page back from the back/forward cache) may have reset or changed the answers: what is
  // stored is the state, and the old in-memory answers are never written back over it.
  function takeState(next) {
    form = next;
    fillFields();
    refresh();
  }

  function onStorage(event) {
    var next = formAfterStorageEvent(event, optionLists);
    if (next !== null) takeState(next);
  }

  function onPageShow(event) {
    if (event.persisted) takeState(loadForm(storage, optionLists, warn));
  }

  fillFields();
  refresh();
  each('[data-sr-needs-script]', function (element) { element.hidden = false; });
  page.addEventListener('click', onClick);
  page.addEventListener('input', onInput);
  page.addEventListener('focusin', onFocus);
  window.addEventListener('storage', onStorage);
  window.addEventListener('pageshow', onPageShow);
  each('[data-sr-reset]', function (button) { button.addEventListener('click', onReset); });
})();
