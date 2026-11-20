// The functions of hosts/site/wwwroot/site.js that decide something without the page: run with
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

// The words are the page's (domains/content/site/Publication.cs writes them into the page); the script only picks one and fills in the number.
var countWords = { none: 'No matches', one: '1 publication available', many: '{count} publications available' };

test('TC-SITE-R33-04 the line above a tab counts the publications shown, in the words the page holds', () => {
  assert.equal(site.countLabel(0, countWords), 'No matches');
  assert.equal(site.countLabel(1, countWords), '1 publication available');
  assert.equal(site.countLabel(12, countWords), '12 publications available');
  assert.equal(site.countLabel(3, { none: 'n', one: 'o', many: 'Alle {count}' }), 'Alle 3');
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

// The words of the article list, as the page writes them into data-article-filters (domains/content/site/ArticleFilters.cs).
var texts = {
  allArticles: 'All Articles',
  defaultDescription: 'Explore our collection of articles on the path of the Ahle Bait (a.s.)',
  tagTitle: 'Articles tagged \u201C{name}\u201D',
  tagDescription: 'Showing all articles with the tag "{name}"',
  tagChip: 'Tag: {name}',
  noneTitle: 'No articles found',
  noneInCategory: ' in this category',
  noneWithTag: ' with tag "{name}"',
  hintTag: 'Try selecting a different tag',
  hintCategory: 'Try selecting a different category',
};

var data = {
  texts: texts,
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

test('TC-SITE-R43-04 the nothing-found words are the page\'s, put together for a category, a tag, or both', () => {
  assert.deepEqual(site.noMatchText({ category: 'a', tag: '' }, texts), {
    title: 'No articles found in this category',
    hint: 'Try selecting a different category',
  });
  assert.deepEqual(site.noMatchText({ category: '', tag: 'x y' }, texts), {
    title: 'No articles found with tag "x y"',
    hint: 'Try selecting a different tag',
  });
  assert.deepEqual(site.noMatchText({ category: 'a', tag: 'x' }, texts), {
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

test('TC-SITE-R43-05 every word comes from the page: other words in the data give other headings', () => {
  var other = JSON.parse(JSON.stringify(data));
  other.texts.defaultDescription = 'Standard';
  other.texts.tagTitle = 'T {name}';
  other.texts.tagChip = 'C {name}';
  assert.equal(site.headingFor({ category: 'foundations', tag: '' }, other).description, 'Standard');
  assert.equal(site.headingFor({ category: '', tag: 'sample tag' }, other).title, 'T Sample Tag');
  assert.equal(site.fill('C {name}', '$& x'), 'C $& x');
});

test('TC-SITE-R52-02 a search is its trimmed text in q, and an empty one goes to the list without q', () => {
  assert.equal(site.searchTarget('/articles/', '  ahl bait  '), '/articles/?q=ahl+bait');
  assert.equal(site.searchTarget('/articles/', 'a&b=c'), '/articles/?q=a%26b%3Dc');
  assert.equal(site.searchTarget('/articles/', ''), '/articles/');
  assert.equal(site.searchTarget('/articles/', '   \t '), '/articles/');
});

test('TC-SITE-R50-03 a part of the page that throws is reported by name and the parts after it still run', () => {
  var ran = [];
  var reports = [];
  var report = function (name, error) {
    reports.push(name + ': ' + error.message);
  };
  site.attempt('first', function () { ran.push('first'); }, report);
  site.attempt('second', function () { throw new Error('boom'); }, report);
  site.attempt('third', function () { ran.push('third'); }, report);
  assert.deepEqual(ran, ['first', 'third']);
  assert.deepEqual(reports, ['second: boom']);
});

// The Lectures page (issue 88, LEC-R4 and LEC-R5): which cards show for a language and a count. The words and the cards are the page's.

test('TC-LEC-R4-02 load more shows the next 24 and stops at the total', () => {
  var groups = new Array(60).fill('en');
  var first = site.lecturesToShow(groups, '', 24);
  var second = site.lecturesToShow(groups, '', 48);
  var third = site.lecturesToShow(groups, '', 72);
  assert.deepEqual(first.show, Array.from({ length: 24 }, (_, i) => i));
  assert.deepEqual(second.show, Array.from({ length: 48 }, (_, i) => i));
  assert.deepEqual(third.show, Array.from({ length: 60 }, (_, i) => i));
  assert.equal(first.total, 60);
  assert.equal(second.total, 60);
  assert.equal(third.total, 60);
});

test('TC-LEC-R5-01 a language shows only its lectures', () => {
  var groups = ['ur-hi', 'en', '', 'ur-hi', 'ar'];
  assert.deepEqual(site.lecturesToShow(groups, 'ur-hi', 24), { show: [0, 3], total: 2 });
  assert.deepEqual(site.lecturesToShow(groups, 'en', 24), { show: [1], total: 1 });
  assert.deepEqual(site.lecturesToShow(groups, '', 24), { show: [0, 1, 2, 3, 4], total: 5 });
  assert.deepEqual(site.lecturesToShow(groups, 'ar', 24), { show: [4], total: 1 });
  assert.deepEqual(site.lecturesToShow(groups, 'ur-hi', 1), { show: [0], total: 2 });
});
