// The two functions of hosts/site/wwwroot/site.js that decide something without the page: run with
//   node --test hosts/site/tests/js/
// Node's own test runner: no package, no build step. site.js hands them over when it is loaded outside a browser.
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const site = require('../../wwwroot/site.js');

test('TC-SITE-R33-02 a publication matches when its text contains what was typed, in any case', () => {
  assert.equal(site.matchesSearch('Holy Quran and Ameerul Momineen', 'quran'), true);
  assert.equal(site.matchesSearch('holy quran', 'QURAN'), true);
  assert.equal(site.matchesSearch('Holy Quran', 'hadith'), false);
  assert.equal(site.matchesSearch('قرآن اور امیر المومنین', 'امیر'), true);
});

test('TC-SITE-R33-03 spaces around what was typed are not searched for, and an empty box matches everything', () => {
  assert.equal(site.matchesSearch('Holy Quran', '  quran  '), true);
  assert.equal(site.matchesSearch('Holy Quran', ''), true);
  assert.equal(site.matchesSearch('Holy Quran', '   '), true);
  assert.equal(site.matchesSearch('Holy Quran', 'holy  quran'), false);
});

test('TC-SITE-R33-04 the line above a tab counts the publications shown, as the present site words it', () => {
  assert.equal(site.countLabel(0), 'No matches');
  assert.equal(site.countLabel(1), '1 publication available');
  assert.equal(site.countLabel(12), '12 publications available');
});
