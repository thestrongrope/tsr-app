/*
 * The edge lane fixtures for the new API's database: the same rows as tools/parity-php/edge-fixtures.sql (read the header there).
 * Loaded by tools/contract-edge.sh before every run; resets every row it owns. Synthetic only: tokens 927002 to 927012 and 927100, 927101, emails edge.<token>@example.invalid.
 */
DELETE FROM platform.admin_access_log WHERE token BETWEEN 927000 AND 927999;

INSERT INTO identity.users (token, email)
SELECT v.token, 'edge.' || v.token || '@example.invalid' FROM (VALUES
  (927002), (927003), (927004), (927005), (927006), (927007), (927008), (927009), (927012), (927100)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'edge.' || u.token || '@example.invalid' WHERE u.token BETWEEN 927000 AND 927999 AND u.email <> 'edge.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Edge Member ' || v.token, CASE WHEN v.token = 927009 THEN NULL ELSE '1' END, '+91000092' || right(v.token::text, 4) FROM (VALUES
  (927002), (927003), (927004), (927005), (927006), (927007), (927008), (927009), (927012), (927100)
) AS v (token)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 927000 AND 927999);
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 3 FROM identity.users WHERE token = 927002;
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 1 FROM identity.users WHERE token IN (927004, 927005, 927006, 927007, 927008, 927009, 927012);

INSERT INTO platform.admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT now() - interval '1 hour', u.id, 927100, 1, '/edge/alpha', 'GET', '192.0.2.1', 'Edge UA', 'https://example.invalid/r' FROM identity.users u WHERE u.token = 927100;
INSERT INTO platform.admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT now() - interval '2 days', u.id, 927100, 3, '/edge/alpha', 'POST', '192.0.2.2', 'Edge UA', NULL FROM identity.users u WHERE u.token = 927100;
INSERT INTO platform.admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT now() - interval '3 days', u.id, 927100, 9, '/edge/=beta', 'GET', '192.0.2.3', '=cmd|calc', '@ref' FROM identity.users u WHERE u.token = 927100;
INSERT INTO platform.admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT now() - interval '4 days', u.id, 927100, NULL, '/edge/gamma', 'GET', NULL, NULL, NULL FROM identity.users u WHERE u.token = 927100;
INSERT INTO platform.admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT now() - interval '40 days', u.id, 927100, 0, '/edge/old', 'GET', '192.0.2.4', 'Edge UA', NULL FROM identity.users u WHERE u.token = 927100;
INSERT INTO platform.admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
VALUES (now() - interval '1 day', NULL, 927101, 1, '/edge/alpha', 'GET', '192.0.2.5', 'Edge UA', NULL);

-- The 114 surahs exactly as PHP's holy_quran holds them (the test stack seeds only three, without the marks), so the list can be compared with PHP byte for byte. Loaded into this TEST stack only.
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (1, 'Al-Fatiha', 'ٱلْفَاتِحَة', 7) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (2, 'Al-Baqara', 'ٱلْبَقَرَة', 286) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (3, 'Aal-E-Imran', 'آلِ عِمْرَان', 200) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (4, 'An-Nisa', 'ٱلنِّسَاء', 176) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (5, 'Al-Ma''idah', 'ٱلْمَائِدَة', 120) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (6, 'Al-An''am', 'ٱلْأَنْعَام', 165) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (7, 'Al-A''raf', 'ٱلْأَعْرَاف', 206) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (8, 'Al-Anfal', 'ٱلْأَنْفَال', 75) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (9, 'At-Tawba', 'ٱلتَّوْبَة', 129) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (10, 'Yunus', 'يُونُس', 109) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (11, 'Hud', 'هُود', 123) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (12, 'Yusuf', 'يُوسُف', 111) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (13, 'Ar-Ra''d', 'ٱلرَّعْد', 43) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (14, 'Ibrahim', 'إِبْرَاهِيم', 52) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (15, 'Al-Hijr', 'ٱلْحِجْر', 99) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (16, 'An-Nahl', 'ٱلنَّحْل', 128) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (17, 'Al-Isra', 'بني إسرائيل', 111) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (18, 'Al-Kahf', 'ٱلْكَهْف', 110) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (19, 'Maryam', 'مَرْيَم', 98) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (20, 'Ta-Ha', 'طه', 135) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (21, 'Al-Anbiya', 'ٱلْأَنْبِيَاء', 112) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (22, 'Al-Hajj', 'ٱلْحَجّ', 78) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (23, 'Al-Mu''minun', 'ٱلْمُؤْمِنُون', 118) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (24, 'An-Nur', 'ٱلنُّور', 64) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (25, 'Al-Furqan', 'ٱلْفُرْقَان', 77) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (26, 'Ash-Shu''ara', 'ٱلشُّعَرَاء', 227) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (27, 'An-Naml', 'ٱلنَّمْل', 93) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (28, 'Al-Qasas', 'ٱلْقَصَص', 88) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (29, 'Al-Ankabut', 'ٱلْعَنْكَبُوت', 69) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (30, 'Ar-Rum', 'ٱلرُّوم', 60) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (31, 'Luqman', 'لُقْمَان', 34) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (32, 'As-Sajda', 'ٱلسَّجْدَة', 30) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (33, 'Al-Ahzab', 'ٱلْأَحْزَاب', 73) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (34, 'Saba', 'سَبَأ', 54) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (35, 'Fatir', 'فَاطِر', 45) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (36, 'Yasin', 'يس', 83) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (37, 'As-Saffat', 'ٱلصَّافَّات', 182) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (38, 'Sad', 'ص', 88) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (39, 'Az-Zumar', 'ٱلزُّمَر', 75) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (40, 'Ghafir', 'غَافِر', 85) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (41, 'Fussilat', 'فُصِّلَت', 54) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (42, 'Ash-Shura', 'ٱلشُّورىٰ', 53) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (43, 'Az-Zukhruf', 'ٱلْزُّخْرُف', 89) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (44, 'Ad-Dukhan', 'ٱلدُّخَان', 59) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (45, 'Al-Jathiya', 'ٱلْجَاثِيَة', 37) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (46, 'Al-Ahqaf', 'ٱلْأَحْقَاف', 35) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (47, 'Muhammad', 'مُحَمَّد', 38) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (48, 'Al-Fath', 'ٱلْفَتْح', 29) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (49, 'Al-Hujurat', 'ٱلْحُجُرَات', 18) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (50, 'Qaf', 'ق', 45) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (51, 'Adh-Dhariyat', 'ٱلذَّارِيَات', 60) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (52, 'At-Tur', 'ٱلطُّور', 49) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (53, 'An-Najm', 'ٱلنَّجْم', 62) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (54, 'Al-Qamar', 'ٱلْقَمَر', 55) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (55, 'Ar-Rahman', 'ٱلرَّحْمَٰن', 78) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (56, 'Al-Waqi''a', 'ٱلْوَاقِعَة', 96) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (57, 'Al-Hadid', 'ٱلْحَدِيد', 29) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (58, 'Al-Mujadila', 'ٱلْمُجَادِلَة', 22) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (59, 'Al-Hashr', 'ٱلْحَشْر', 24) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (60, 'Al-Mumtahina', 'ٱلْمُمْتَحَنَة', 13) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (61, 'As-Saff', 'ٱلصَّفّ', 14) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (62, 'Al-Jumu''ah', 'ٱلْجُمُعَة', 11) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (63, 'Al-Munafiqoon', 'ٱلْمُنَافِقُون', 11) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (64, 'At-Taghabun', 'ٱلتَّغَابُن', 18) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (65, 'At-Talaq', 'ٱلطَّلَاق', 12) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (66, 'At-Tahrim', 'ٱلتَّحْرِيم', 12) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (67, 'Al-Mulk', 'ٱلْمُلْك', 30) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (68, 'Al-Qalam', 'ٱلْقَلَم', 52) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (69, 'Al-Haaqqa', 'ٱلْحَاقَّة', 52) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (70, 'Al-Ma''arij', 'ٱلْمَعَارِج', 44) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (71, 'Nooh', 'نُوح', 28) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (72, 'Al-Jinn', 'ٱلْجِنّ', 28) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (73, 'Al-Muzzammil', 'ٱلْمُزَّمِّل', 20) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (74, 'Al-Muddaththir', 'ٱلْمُدَّثِّر', 56) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (75, 'Al-Qiyama', 'ٱلْقِيَامَة', 40) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (76, 'Al-Insan', 'ٱلْإِنْسَان', 31) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (77, 'Al-Mursalat', 'ٱلْمُرْسَلَات', 50) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (78, 'An-Naba', 'ٱلنَّبَأ', 40) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (79, 'An-Naziat', 'ٱلنَّازِعَات', 46) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (80, 'Abasa', 'عَبَسَ', 42) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (81, 'At-Takwir', 'ٱلتَّكْوِير', 29) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (82, 'Al-Infitar', 'ٱلْإِنْفِطَار', 19) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (83, 'Al-Mutaffifin', 'ٱلْمُطَفِّفِين', 36) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (84, 'Al-Inshiqaq', 'ٱلْإِنْشِقَاق', 25) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (85, 'Al-Buruj', 'ٱلْبُرُوج', 22) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (86, 'At-Tariq', 'ٱلطَّارِق', 17) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (87, 'Al-A''la', 'ٱلْأَعْلَىٰ', 19) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (88, 'Al-Ghashiya', 'ٱلْغَاشِيَة', 26) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (89, 'Al-Fajr', 'ٱلْفَجْر', 30) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (90, 'Al-Balad', 'ٱلْبَلَد', 20) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (91, 'Ash-Shams', 'ٱلشَّمْس', 15) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (92, 'Al-Layl', 'ٱللَّيْل', 21) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (93, 'Ad-Duhaa', 'ٱلضُّحَىٰ', 11) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (94, 'Al-Inshirah', 'ٱلشَّرْح', 8) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (95, 'At-Tin', 'ٱلتِّين', 8) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (96, 'Al-Alaq', 'ٱلْعَلَق', 19) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (97, 'Al-Qadr', 'ٱلْقَدْر', 5) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (98, 'Al-Bayyina', 'ٱلْبَيِّنَة', 8) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (99, 'Al-Zalzala', 'ٱلزَّلْزَلَة', 8) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (100, 'Al-Adiyat', 'ٱلْعَادِيَات', 11) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (101, 'Al-Qaria', 'ٱلْقَارِعَة', 11) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (102, 'At-Takathur', 'ٱلتَّكَاثُر', 8) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (103, 'Al-Asr', 'ٱلْعَصْر', 3) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (104, 'Al-Humaza', 'ٱلْهُمَزَة', 9) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (105, 'Al-Fil', 'ٱلْفِيل', 5) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (106, 'Quraish', 'قُرَيْش', 4) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (107, 'Al-Ma''un', 'ٱلْمَاعُون', 7) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (108, 'Al-Kawthar', 'ٱلْكَوْثَر', 3) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (109, 'Al-Kafiroon', 'ٱلْكَافِرُون', 6) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (110, 'An-Nasr', 'ٱلنَّصْر', 3) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (111, 'Al-Masad', 'ٱلْمَسَد', 5) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (112, 'Al-Ikhlas', 'ٱلْإِخْلَاص', 4) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (113, 'Al-Falaq', 'ٱلْفَلَق', 5) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
INSERT INTO content.holy_quran (id, surah, arabic, verses) VALUES (114, 'An-Nas', 'ٱلنَّاس', 6) ON CONFLICT (id) DO UPDATE SET surah = excluded.surah, arabic = excluded.arabic, verses = excluded.verses;
