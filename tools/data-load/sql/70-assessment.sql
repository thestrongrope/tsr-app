-- Data load, domain assessment: one transaction. Row refusals are counted by staging.load_table, never raised.
begin;
select staging.load_table('assessment', 'quiz_campaigns', 'assessment.quiz_campaigns');
select staging.load_table('assessment', 'standard_mcqs', 'assessment.standard_mcqs');
select staging.load_table('assessment', 'standard_mcq_questions', 'assessment.standard_mcq_questions');
select staging.load_table('assessment', 'spot_quizzes', 'assessment.spot_quizzes');
select staging.load_table('assessment', 'spot_quiz_questions', 'assessment.spot_quiz_questions');
select staging.load_table('assessment', 'spot_quiz_responses', 'assessment.spot_quiz_responses');
select staging.load_table('assessment', 'spot_quiz_submissions', 'assessment.spot_quiz_submissions');
commit;
