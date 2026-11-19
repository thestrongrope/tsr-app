// The functions of hosts/site/wwwroot/self-reflection.js that decide something without the page: the scoring rules, the
// reading and writing of the saved form. Run with
//   node --test hosts/site/tests/js/
// Every expected number below was worked out by hand from the present website's rules (tsr-web app/self-reflection/[lang]/page.tsx),
// not by running the script. Which of the page's buttons is wired to what is the DOM part of the script and is not tested here.
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const reflection = require('../../wwwroot/self-reflection.js');

// The best answers of every section: section 1 yes, yes, yes, no, no, no (6); section 2 positions 1, 1, any, 0, 0 (5);
// section 4 all strong (5); section 5 a step chosen and a plan of more than 30 characters (3).
function best() {
  var form = reflection.emptyForm();
  form.checks = [true, true, true, false, false, false];
  form.choices = [1, 1, 2, 0, 0];
  form.traits = ['strong', 'strong', 'strong', 'strong', 'strong'];
  form.choice = 0;
  form.plan = 'x'.repeat(31);
  return form;
}

// The worst answers: everything answered, nothing scores.
function worst() {
  var form = reflection.emptyForm();
  form.checks = [false, false, false, true, true, true];
  form.choices = [0, 0, null, 1, 1];
  form.traits = ['weak', 'weak', 'weak', 'weak', 'weak'];
  return form;
}

test('TC-SITE-R62-01 all best answers score 6, 5, 5, 3: total 19, the top range', () => {
  var result = reflection.summarize(best());
  assert.deepEqual(result.scores, [6, 5, 5, 3]);
  assert.equal(result.total, 19);
  assert.equal(result.totalText, '19.0');
  assert.equal(result.range, 0);
  assert.equal(result.percent, 100);
});

test('TC-SITE-R62-02 all worst answers score nothing: total 0, the bottom range, 0 percent', () => {
  var result = reflection.summarize(worst());
  assert.deepEqual(result.scores, [0, 0, 0, 0]);
  assert.equal(result.total, 0);
  assert.equal(result.totalText, '0.0');
  assert.equal(result.range, 3);
  assert.equal(result.percent, 0);
});

test('TC-SITE-R62-03 the empty form scores nothing, like the worst answers, and the weakest section is the first', () => {
  var result = reflection.summarize(reflection.emptyForm());
  assert.deepEqual(result.scores, [0, 0, 0, 0]);
  assert.equal(result.range, 3);
  assert.equal(result.weakest, 0);
});

test('TC-SITE-R62-04 section 1: the first three score for yes, the last three score for no, an unanswered one scores nothing', () => {
  var form = reflection.emptyForm();
  form.checks = [true, null, false, null, false, true];
  // yes on the first (1), nothing on the second, no on the third (0); the fourth nothing, no on the fifth (1), yes on the sixth (0).
  assert.equal(reflection.sectionScores(form)[0], 2);
});

test('TC-SITE-R62-05 section 2: Effort, Alone, Repent and Purpose score by position; any struggle named scores', () => {
  var form = reflection.emptyForm();
  form.choices = [1, null, null, null, null];
  assert.equal(reflection.sectionScores(form)[1], 1);
  form.choices = [0, 0, null, 1, 1];
  assert.equal(reflection.sectionScores(form)[1], 0);
  form.choices = [null, null, 0, null, null];
  assert.equal(reflection.sectionScores(form)[1], 1);
  form.choices = [null, null, 3, null, null];
  assert.equal(reflection.sectionScores(form)[1], 1);
  form.choices = [null, 1, null, 0, 0];
  assert.equal(reflection.sectionScores(form)[1], 3);
});

test('TC-SITE-R63-01 section 2 is scored by position: the three languages score the same, and no text is read', () => {
  var form = reflection.emptyForm();
  form.choices = [1, 1, 3, 0, 0];
  assert.equal(reflection.sectionScores(form)[1], 5);
  assert.ok(!/Effort|Alone|Repent|Purpose|کوشش|મહેનત/.test(fs.readFileSync(path.join(__dirname, '../../wwwroot/self-reflection.js'), 'utf8')));
});

test('TC-SITE-R62-06 section 4: strong 1, inconsistent 0.5, weak 0, so a total can end in .5', () => {
  var form = reflection.emptyForm();
  form.traits = ['strong', 'inconsistent', 'weak', null, 'inconsistent'];
  assert.equal(reflection.sectionScores(form)[2], 2);
  form.traits = ['inconsistent', null, null, null, null];
  var result = reflection.summarize(form);
  assert.equal(result.total, 0.5);
  assert.equal(result.totalText, '0.5');
  assert.equal(result.percent, 3);
});

test('TC-SITE-R62-07 section 5: a step is 1, other needs text, a plan over 30 characters is 2, a shorter plan 1, the section tops at 3', () => {
  function score(choice, other, plan) {
    var form = reflection.emptyForm();
    form.choice = choice;
    form.other = other;
    form.plan = plan;
    return reflection.sectionScores(form)[3];
  }
  assert.equal(score(null, '', ''), 0);
  assert.equal(score(0, '', ''), 1);
  assert.equal(score(4, '', ''), 1);
  assert.equal(score(5, '', ''), 0);
  assert.equal(score(5, '   ', ''), 0);
  assert.equal(score(5, 'Teach', ''), 1);
  assert.equal(score(null, '', 'a'), 1);
  assert.equal(score(null, '', '   '), 0);
  assert.equal(score(null, '', 'x'.repeat(30)), 1);
  assert.equal(score(null, '', 'x'.repeat(31)), 2);
  assert.equal(score(null, '', ' ' + 'x'.repeat(30) + ' '), 1);
  assert.equal(score(2, '', 'x'.repeat(31)), 3);
  assert.equal(score(5, 'Teach', 'x'.repeat(31)), 3);
});

test('TC-SITE-R62-08 the range that applies, at each boundary', () => {
  assert.equal(reflection.rangeFor(19), 0);
  assert.equal(reflection.rangeFor(15), 0);
  assert.equal(reflection.rangeFor(14.5), 1);
  assert.equal(reflection.rangeFor(11), 1);
  assert.equal(reflection.rangeFor(10.5), 2);
  assert.equal(reflection.rangeFor(6), 2);
  assert.equal(reflection.rangeFor(5.5), 3);
  assert.equal(reflection.rangeFor(0), 3);
});

test('TC-SITE-R62-09 the weakest section is the lowest share of its own maximum; a tie keeps the first', () => {
  // 3/6, 2/5, 5/5, 3/3: shares 0.5, 0.4, 1, 1 -> section 2 (index 1).
  assert.equal(reflection.weakestOf([3, 2, 5, 3]), 1);
  // 3/6 and 2.5/5 are both one half: the first of them wins.
  assert.equal(reflection.weakestOf([3, 5, 2.5, 3]), 0);
  assert.equal(reflection.weakestOf([6, 5, 2.5, 3]), 2);
  assert.equal(reflection.weakestOf([6, 5, 5, 0]), 3);
  assert.equal(reflection.weakestOf([6, 5, 5, 3]), 0);
  // 1/3 against 2/6: equal shares, the first (section 1) wins.
  assert.equal(reflection.weakestOf([2, 5, 5, 1]), 0);
});

test('TC-SITE-R62-10 the percent is the total of 19, rounded', () => {
  assert.equal(reflection.progressPercent(0), 0);
  assert.equal(reflection.progressPercent(19), 100);
  assert.equal(reflection.progressPercent(9.5), 50);
  assert.equal(reflection.progressPercent(1), 5);
  assert.equal(reflection.progressPercent(14.5), 76);
});

// The option lists of section 2 in the three languages, as the page hands them over (a few of the real words).
var options = [
  [['Words', 'Effort'], ['Watched', 'Alone'], ['Desire', 'Ego', 'Fear', 'Laziness'], ['Repent', 'Repeat'], ['Purpose', 'Distraction']],
  [['باتیں', 'کوشش'], ['جب کوئی دیکھ رہا ہو', 'جب اکیلا ہوں'], ['خواہش', 'انا', 'خوف', 'سستی'], ['توبہ', 'دہرانا'], ['ہدف تک', 'ہدف سے دور']],
   [['શબ્દો', 'મહેનત'], ['જોવાય', 'એકલા'], ['ઇચ્છા', 'અહંકાર', 'ડર', 'આળસ'], ['તોબા', 'પુનરાવર્તન'], ['હેતુ', 'વિક્ષેપ']],
];

function saved(extra) {
  return JSON.stringify(Object.assign({
    section1Checks: [true, false, null, null, null, null],
    section1Reflection: 'one',
    section2Choices: ['Effort', null, 'Ego', null, 'Purpose'],
    section2Reflection: 'two',
    section3Answers: ['a', 'b', 'c', 'd'],
    section4Traits: ['strong', null, null, null, 'weak'],
    section4Reflection: 'four',
    section5Choice: 5,
    section5Other: 'other',
    section5Plan: 'plan',
    covenant: 'covenant',
    lastUpdated: '2026-11-18T10:00:00.000Z',
  }, extra));
}

test('TC-SITE-R64-01 a form the present site saved loads as it was, section 2 as positions', () => {
  var form = reflection.parseStored(saved(), options);
  assert.deepEqual(form.checks, [true, false, null, null, null, null]);
  assert.equal(form.reflection1, 'one');
  assert.deepEqual(form.choices, [1, null, 1, null, 0]);
  assert.equal(form.reflection2, 'two');
  assert.deepEqual(form.answers3, ['a', 'b', 'c', 'd']);
  assert.deepEqual(form.traits, ['strong', null, null, null, 'weak']);
  assert.equal(form.reflection4, 'four');
  assert.equal(form.choice, 5);
  assert.equal(form.other, 'other');
  assert.equal(form.plan, 'plan');
  assert.equal(form.covenant, 'covenant');
});

test('TC-SITE-R64-02 a section 2 answer saved in any of the three languages loads on the page of any other', () => {
  var urdu = reflection.parseStored(saved({ section2Choices: ['کوشش', 'جب اکیلا ہوں', 'سستی', 'توبہ', 'ہدف تک'] }), options);
  var gujarati = reflection.parseStored(saved({ section2Choices: ['મહેનત', 'એકલા', 'આળસ', 'તોબા', 'હેતુ'] }), options);
  assert.deepEqual(urdu.choices, [1, 1, 3, 0, 0]);
  assert.deepEqual(gujarati.choices, [1, 1, 3, 0, 0]);
  // A word that is none of the question's options is no answer.
  assert.deepEqual(reflection.parseStored(saved({ section2Choices: ['Alone', null, null, null, null] }), options).choices, [null, null, null, null, null]);
});

test('TC-SITE-R64-03 no option of one question is the same word as another option of that question in any language', () => {
  var page = JSON.parse(fs.readFileSync(path.join(__dirname, '../../../../domains/content/site/self-reflection.json'), 'utf8'));
  for (var q = 0; q < 5; q++) {
    var words = ['en', 'ur', 'gu'].flatMap(function (lang) { return page[lang].section2.questions[q].options; });
    assert.equal(new Set(words).size, words.length, 'question ' + q);
  }
});

test('TC-SITE-R64-04 what is written is the present site\'s shape: option words, one key, a time', () => {
  var form = reflection.parseStored(saved(), options);
  var written = reflection.toStored(form, options[1], '2026-11-18T11:00:00.000Z');
  assert.deepEqual(Object.keys(written), [
    'section1Checks', 'section1Reflection', 'section2Choices', 'section2Reflection', 'section3Answers', 'section4Traits',
    'section4Reflection', 'section5Choice', 'section5Other', 'section5Plan', 'covenant', 'lastUpdated']);
  // The saved answers were given in English: the words stay as stored (TC-SITE-R64-06 covers the change of an answer).
  assert.deepEqual(written.section2Choices, ['Effort', null, 'Ego', null, 'Purpose']);
  assert.equal(written.section5Choice, 5);
  assert.equal(written.lastUpdated, '2026-11-18T11:00:00.000Z');
  assert.equal(reflection.STORAGE_KEY, 'tsr-self-reflection');
});

test('TC-SITE-R68-01 stored text that is no form starts the form empty and never throws', () => {
  var empty = reflection.emptyForm();
  [null, '', 'null', '[]', '42', '"text"', 'true', '{not json', '{"section1Checks":', 'undefined'].forEach(function (text) {
    assert.deepEqual(reflection.parseStored(text, options), empty, String(text));
  });
});

test('TC-SITE-R68-02 a field of the wrong type or shape starts the whole form empty', () => {
  var empty = reflection.emptyForm();
  [
    { section1Checks: 'yes' },
    { section1Checks: [true, false] },
    { section1Checks: [1, 0, null, null, null, null] },
    { section1Reflection: 5 },
    { section2Choices: [1, null, null, null, null] },
    { section2Choices: ['Effort'] },
    { section3Answers: ['a', 'b', 'c'] },
    { section3Answers: ['a', 'b', 'c', 4] },
    { section4Traits: ['great', null, null, null, null] },
    { section5Choice: 6 },
    { section5Choice: -1 },
    { section5Choice: 1.5 },
    { section5Choice: '2' },
    { section5Other: [] },
    { covenant: { a: 1 } },
  ].forEach(function (bad) {
    assert.deepEqual(reflection.parseStored(saved(bad), options), empty, JSON.stringify(bad));
  });
});

test('TC-SITE-R68-03 a missing or null field takes its empty value, as the present site\'s ?? does; extra keys are ignored', () => {
  var form = reflection.parseStored('{"covenant":"mine","section5Choice":null,"section1Checks":null,"other":1}', options);
  var expected = reflection.emptyForm();
  expected.covenant = 'mine';
  assert.deepEqual(form, expected);
});

test('TC-SITE-R68-04 storage that throws on reading starts the form empty; one that throws on writing reports it', () => {
  var broken = { getItem: function () { throw new Error('denied'); }, setItem: function () { throw new Error('full'); }, removeItem: function () { throw new Error('denied'); } };
  assert.deepEqual(reflection.loadForm(function () { return broken; }, options), reflection.emptyForm());
  assert.equal(reflection.saveForm(function () { return broken; }, reflection.emptyForm(), options[0], 'now'), false);
  assert.equal(reflection.clearForm(function () { return broken; }), false);
});

test('TC-SITE-R68-05 a browser that throws when localStorage is touched at all starts the form empty and the page keeps working', () => {
  function blocked() { throw new Error('SecurityError'); }
  assert.deepEqual(reflection.loadForm(blocked, options), reflection.emptyForm());
  assert.equal(reflection.saveForm(blocked, reflection.emptyForm(), options[0], 'now'), false);
  assert.equal(reflection.clearForm(blocked), false);
});

test('TC-SITE-R64-05 saving writes the form under the key, and loading it again gives the same form', () => {
  var memory = {};
  var storage = {
    getItem: function (key) { return key in memory ? memory[key] : null; },
    setItem: function (key, value) { memory[key] = value; },
    removeItem: function (key) { delete memory[key]; },
  };
  var form = best();
  form.reflection1 = 'honest';
  form.answers3 = ['a', '', '', 'd'];
  form.covenant = 'I commit';
  assert.equal(reflection.saveForm(function () { return storage; }, form, options[2], '2026-11-18T12:00:00.000Z'), true);
  assert.deepEqual(Object.keys(memory), ['tsr-self-reflection']);
  // Loading keeps the words the answers were stored in (here the Gujarati ones the page wrote).
  form.choiceWords = form.choices.map(function (at, q) { return options[2][q][at]; });
  assert.deepEqual(reflection.loadForm(function () { return storage; }, options), form);
});

test('TC-SITE-R65-01 reset removes the saved form and nothing is written back', () => {
  var memory = { 'tsr-self-reflection': saved(), theme: 'dark' };
  var storage = {
    getItem: function (key) { return key in memory ? memory[key] : null; },
    setItem: function (key, value) { memory[key] = value; },
    removeItem: function (key) { delete memory[key]; },
  };
  assert.equal(reflection.clearForm(function () { return storage; }), true);
  assert.deepEqual(Object.keys(memory), ['theme']);
  assert.deepEqual(reflection.loadForm(function () { return storage; }, options), reflection.emptyForm());
});

test('TC-SITE-R66-01 the script asks for nothing after the page has loaded', () => {
  var script = fs.readFileSync(path.join(__dirname, '../../wwwroot/self-reflection.js'), 'utf8');
  ['fetch', 'XMLHttpRequest', 'sendBeacon', 'WebSocket', 'EventSource', 'import(', 'importScripts', 'document.cookie', '.submit('].forEach(function (name) {
    assert.ok(!script.includes(name), name);
  });
});

test('TC-SITE-R64-06 (M2) a section 2 answer keeps the words it was stored in unless the reader changes that answer', () => {
  var english = saved({ section2Choices: ['Effort', 'Alone', 'Ego', 'Repent', 'Purpose'] });
  var form = reflection.parseStored(english, options);
  form.reflection1 = 'changed on the Urdu page';
  assert.deepEqual(reflection.toStored(form, options[1], 'now').section2Choices, ['Effort', 'Alone', 'Ego', 'Repent', 'Purpose']);
  reflection.chooseOption(form, 1, 0);
  assert.deepEqual(reflection.toStored(form, options[1], 'now').section2Choices, ['Effort', 'جب کوئی دیکھ رہا ہو', 'Ego', 'Repent', 'Purpose']);
  reflection.chooseOption(form, 1, 0);
  assert.deepEqual(reflection.toStored(form, options[1], 'now').section2Choices, ['Effort', null, 'Ego', 'Repent', 'Purpose']);
  assert.deepEqual(form.choices, [1, null, 1, 0, 0]);
});

test('TC-SITE-R64-07 (M2) a reader who chooses an answer on a page writes that page\'s words', () => {
  var form = reflection.emptyForm();
  reflection.chooseOption(form, 0, 1);
  assert.deepEqual(reflection.toStored(form, options[2], 'now').section2Choices, ['મહેનત', null, null, null, null]);
});

test('TC-SITE-R65-02 (L1) a change of the page\'s key in another tab is the page\'s new state', () => {
  var key = reflection.STORAGE_KEY;
  var removed = reflection.formAfterStorageEvent({ key: key, newValue: null }, options);
  assert.deepEqual(removed, reflection.emptyForm());
  var cleared = reflection.formAfterStorageEvent({ key: null, newValue: null }, options);
  assert.deepEqual(cleared, reflection.emptyForm());
  var changed = reflection.formAfterStorageEvent({ key: key, newValue: saved() }, options);
  assert.equal(changed.reflection1, 'one');
  assert.deepEqual(changed.choices, [1, null, 1, null, 0]);
});

test('TC-SITE-R65-03 (L1) a change of any other key leaves the page\'s state alone', () => {
  assert.equal(reflection.formAfterStorageEvent({ key: 'theme', newValue: 'dark' }, options), null);
});

test('TC-SITE-R68-06 (m3) stored data that is discarded is reported once, with no answer in the message; no data and good data are not', () => {
  function reasons(text) {
    var told = [];
    reflection.parseStored(text, options, function (reason) { told.push(reason); });
    return told;
  }
  assert.equal(reasons(null).length, 0);
  assert.equal(reasons(saved()).length, 0);
  assert.equal(reasons('{not json').length, 1);
  assert.equal(reasons('[]').length, 1);
  assert.equal(reasons(saved({ section1Reflection: 'secret words', section5Choice: 6 })).length, 1);
  assert.ok(!reasons(saved({ section1Reflection: 'secret words', section5Choice: 6 }))[0].includes('secret'));
  var told = [];
  var broken = function () { throw new Error('denied'); };
  reflection.loadForm(broken, options, function (reason) { told.push(reason); });
  assert.equal(told.length, 1);
});
