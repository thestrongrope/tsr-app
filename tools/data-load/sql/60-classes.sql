-- Data load, domain classes: one transaction. Row refusals are counted by staging.load_table, never raised.
begin;
select staging.load_table('classes', 'class_levels', 'classes.class_levels');
select staging.load_table('classes', 'tags', 'classes.tags');
select staging.load_table('classes', 'topics', 'classes.topics');
select staging.load_table('classes', 'teachers', 'classes.teachers');
select staging.load_table('classes', 'teachers_history', 'classes.teachers_history');
select staging.load_table('classes', 'classes', 'classes.classes');
select staging.load_table('classes', 'class_schedules', 'classes.class_schedules');
select staging.load_table('classes', 'class_schedule_topics', 'classes.class_schedule_topics');
select staging.load_table('classes', 'class_sessions', 'classes.class_sessions');
select staging.load_table('classes', 'class_attendance', 'classes.class_attendance');
select staging.load_table('classes', 'class_students', 'classes.class_students');
select staging.load_table('classes', 'class_tags', 'classes.class_tags');
select staging.load_table('classes', 'class_audit_log', 'classes.class_audit_log');
select staging.load_table('classes', 'guides', 'classes.guides');
select staging.load_table('classes', 'student_transfers', 'classes.student_transfers');
select staging.load_table('classes', 'syllabus', 'classes.syllabus');
commit;
