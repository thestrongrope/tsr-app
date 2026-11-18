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

// The article list's filters (issue 67, SITE-R40 to R44). The rules of which cards and which words are the build's
// (hosts/site/tests/ArticleFilterTests.cs); these are the script's own: reading the address and comparing.

test('TC-SITE-R41-04 slugify is the present site\'s function: lower case, runs of other characters become one dash, no dash at the ends', () => {
  assert.equal(site.slugify('Sample Tag'), 'sample-tag');
  assert.equal(site.slugify('  Ahl-e  Bait!! '), 'ahl-e-bait');
  assert.equal(site.slugify('--a--b--'), 'a-b');
  assert.equal(site.slugify('UPPER_case 42'), 'upper-case-42');
  assert.equal(site.slugify('قرآن'), '');
  assert.equal(site.slugify(''), '');
  assert.equal(site.slugify('İstanbul'), 'i-stanbul');
});

test('TC-SITE-R40-07 the filter is read from the address: the first value of category and tag, decoded, empty when absent', () => {
  assert.deepEqual(site.readFilter(''), { category: '', tag: '' });
  assert.deepEqual(site.readFilter('?category=core-terms'), { category: 'core-terms', tag: '' });
  assert.deepEqual(site.readFilter('?tag=Sample%20Tag&category=a'), { category: 'a', tag: 'Sample Tag' });
  assert.deepEqual(site.readFilter('?tag=a+b'), { category: '', tag: 'a b' });
  assert.deepEqual(site.readFilter('?category=a&category=b'), { category: 'a', tag: '' });
  assert.deepEqual(site.readFilter('?q=search&category='), { category: '', tag: '' });
});

test('TC-SITE-R40-08 a card matches a category only when its list holds that slug whole', () => {
  var none = { category: '', tag: '' };
  assert.equal(site.matchesFilter('|core-terms|foundations|', '', { category: 'core-terms', tag: '' }), true);
  assert.equal(site.matchesFilter('|core-terms|foundations|', '', { category: 'core', tag: '' }), false);
  assert.equal(site.matchesFilter('|core-terms|foundations|', '', { category: 'Core-Terms', tag: '' }), false);
  assert.equal(site.matchesFilter('', '', { category: 'core-terms', tag: '' }), false);
  assert.equal(site.matchesFilter('|core-terms|foundations|', '', { category: 'core-terms|foundations', tag: '' }), false);
  assert.equal(site.matchesFilter('', '', none), true);
});

test('TC-SITE-R41-05 a card matches a tag by the slugified form: the exact name, another case and a slug all find it', () => {
  var tags = '|sample-tag|other|';
  assert.equal(site.matchesFilter('', tags, { category: '', tag: 'Sample Tag' }), true);
  assert.equal(site.matchesFilter('', tags, { category: '', tag: 'sample tag' }), true);
  assert.equal(site.matchesFilter('', tags, { category: '', tag: 'sample-tag' }), true);
  assert.equal(site.matchesFilter('', tags, { category: '', tag: 'SAMPLE  TAG' }), true);
  assert.equal(site.matchesFilter('', tags, { category: '', tag: 'sample' }), false);
  assert.equal(site.matchesFilter('', '', { category: '', tag: 'Sample Tag' }), false);
});

test('TC-SITE-R41-06 a tag with no Latin letter slugifies to nothing and matches only the cards that hold such a tag, as on the present site', () => {
  assert.equal(site.matchesFilter('', '|a||', { category: '', tag: 'قرآن' }), true);
  assert.equal(site.matchesFilter('', '|a|', { category: '', tag: 'قرآن' }), false);
});

test('TC-SITE-R41-07 a category and a tag together must both match', () => {
  var filter = { category: 'a', tag: 'x' };
  assert.equal(site.matchesFilter('|a|', '|x|', filter), true);
  assert.equal(site.matchesFilter('|a|', '|y|', filter), false);
  assert.equal(site.matchesFilter('|b|', '|x|', filter), false);
});

var data = {
  categories: {
    'core-terms': { title: 'Core Terms', parent: 'Foundations', description: 'About core terms.', chip: 'Core Terms' },
    foundations: { title: 'Foundations' },
  },
  tags: { 'sample-tag': 'Sample Tag' },
};

test('TC-SITE-R40-09 the heading of a category has its parent\'s title before it and its own description under it', () => {
  assert.deepEqual(site.headingFor({ category: 'core-terms', tag: '' }, data), {
    parent: 'Foundations',
    title: 'Core Terms',
    description: 'About core terms.',
  });
  assert.deepEqual(site.headingFor({ category: 'foundations', tag: '' }, data), {
    parent: '',
    title: 'Foundations',
    description: 'Explore our collection of articles on the path of the Ahle Bait (a.s.)',
  });
});

test('TC-SITE-R41-08 the heading of a tag names it as the articles spell it, or as typed when no article has it', () => {
  assert.deepEqual(site.headingFor({ category: '', tag: 'SAMPLE tag' }, data), {
    parent: '',
    title: 'Articles tagged “Sample Tag”',
    description: 'Showing all articles with the tag "Sample Tag"',
  });
  assert.equal(site.headingFor({ category: '', tag: 'unknown tag' }, data).title, 'Articles tagged “unknown tag”');
  // A tag wins over a category, as on the present site.
  assert.equal(site.headingFor({ category: 'core-terms', tag: 'sample tag' }, data).parent, '');
});

test('TC-SITE-R43-03 an unknown category is headed by its slug and gets the default description; no filter is All Articles', () => {
  assert.deepEqual(site.headingFor({ category: 'nope', tag: '' }, data), {
    parent: '',
    title: 'nope',
    description: 'Explore our collection of articles on the path of the Ahle Bait (a.s.)',
  });
  assert.equal(site.headingFor({ category: '', tag: '' }, data).title, 'All Articles');
  // A name that exists on every object is still not a category.
  assert.equal(site.headingFor({ category: 'constructor', tag: '' }, data).title, 'constructor');
  assert.equal(site.headingFor({ category: '', tag: 'toString' }, data).title, 'Articles tagged “toString”');
});

test('TC-SITE-R43-04 the nothing-found words are the present site\'s: category, tag, or both', () => {
  assert.deepEqual(site.noMatchText({ category: 'a', tag: '' }), {
    title: 'No articles found in this category',
    hint: 'Try selecting a different category',
  });
  assert.deepEqual(site.noMatchText({ category: '', tag: 'x y' }), {
    title: 'No articles found with tag "x y"',
    hint: 'Try selecting a different tag',
  });
  assert.deepEqual(site.noMatchText({ category: 'a', tag: 'x' }), {
    title: 'No articles found in this category with tag "x"',
    hint: 'Try selecting a different tag',
  });
});

test('TC-SITE-R42-05 a panel link is current for its own slug, an ancestor for a parent of the current one, else neither', () => {
  assert.equal(site.linkState('core-terms', 'core-terms', ''), 'current');
  assert.equal(site.linkState('core-terms', 'foundations', '|core-terms|empty|'), 'ancestor');
  assert.equal(site.linkState('other', 'foundations', '|core-terms|'), 'none');
  assert.equal(site.linkState('', 'foundations', '|core-terms|'), 'none');
  assert.equal(site.linkState('core-terms', 'solo', ''), 'none');
});

test('TC-SITE-R42-06 the chip names a category the panel lists, else shows the slug', () => {
  assert.equal(site.chipTitle('core-terms', data), 'Core Terms');
  assert.equal(site.chipTitle('foundations', data), 'foundations');
  assert.equal(site.chipTitle('nope', data), 'nope');
  assert.equal(site.chipTitle('constructor', data), 'constructor');
});
