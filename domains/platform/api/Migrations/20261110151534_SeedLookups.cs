using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Platform.Api.Migrations
{
    /// <inheritdoc />
    public partial class SeedLookups : Migration
    {
        // The seven class request lists (education, field_of_study, professional_courses, occupation_type, field_of_work,
        // years_experience, role_level), 72 options, copied from tsr-account's migrations/2026_08_21_lookups_table.sql so the
        // seed cannot disagree with PHP. Ids follow the insert order (1 to 72), as on PHP. Later list changes go in a new migration.
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                insert into platform.lookups (type, code, label, sort_order) values
                  ('education', 'doctorate_phd_dphil', 'Doctorate (PhD / DPhil)', 10),
                  ('education', 'graduate_bachelor_s_degree', 'Graduate (Bachelor''s Degree)', 20),
                  ('education', 'islamic_religious_studies_hawza_madrasah_etc', 'Islamic / Religious Studies (Hawza, Madrasah, etc.)', 30),
                  ('education', 'not_applicable_prefer_not_to_say', 'Not Applicable / Prefer not to say', 40),
                  ('education', 'other_learning_self_taught_skills', 'Other Learning / Self-taught Skills', 50),
                  ('education', 'postgraduate_master_s_degree_and_above', 'Postgraduate (Master''s Degree and above)', 60),
                  ('education', 'professional_course_ca_cfa_cs_diploma_certification_etc', 'Professional Course (CA, CFA, CS, Diploma, Certification, etc.)', 70),
                  ('education', 'undergraduate_up_to_grade_14', 'Undergraduate (up to Grade 14)', 80),
                  ('field_of_study', 'agriculture_veterinary_environmental_studies', 'Agriculture / Veterinary / Environmental Studies', 10),
                  ('field_of_study', 'arts_humanities', 'Arts / Humanities', 20),
                  ('field_of_study', 'commerce', 'Commerce', 30),
                  ('field_of_study', 'design_architecture', 'Design / Architecture', 40),
                  ('field_of_study', 'education', 'Education', 50),
                  ('field_of_study', 'engineering_technology_non_it_streams', 'Engineering / Technology (non-IT streams)', 60),
                  ('field_of_study', 'islamic_religious_studies', 'Islamic / Religious Studies', 70),
                  ('field_of_study', 'it_computer_applications_ai_ml', 'IT, Computer Applications, AI / ML', 80),
                  ('field_of_study', 'law', 'Law', 90),
                  ('field_of_study', 'management', 'Management', 100),
                  ('field_of_study', 'media_communication', 'Media / Communication', 110),
                  ('field_of_study', 'medicine_healthcare', 'Medicine / Healthcare', 120),
                  ('field_of_study', 'not_applicable_prefer_not_to_say', 'Not Applicable / Prefer not to say', 130),
                  ('field_of_study', 'other', 'Other', 140),
                  ('field_of_study', 'science', 'Science', 150),
                  ('professional_courses', 'finance_accounting_certifications_ca_cs_cma_acca_cpa_cfa_frm', 'Finance & Accounting Certifications (CA, CS, CMA, ACCA, CPA, CFA, FRM)', 10),
                  ('professional_courses', 'data_analytics', 'Data / Analytics', 20),
                  ('professional_courses', 'cloud_certifications_aws_azure_gcp', 'Cloud Certifications (AWS / Azure / GCP)', 30),
                  ('professional_courses', 'project_management_pmp_prince2_agile_scrum', 'Project Management (PMP / PRINCE2 / Agile / Scrum)', 40),
                  ('professional_courses', 'six_sigma_lean', 'Six Sigma / Lean', 50),
                  ('professional_courses', 'sap_oracle_erp', 'SAP / Oracle / ERP', 60),
                  ('professional_courses', 'teaching_education_diploma', 'Teaching / Education Diploma', 70),
                  ('professional_courses', 'islamic_studies_certificate_course', 'Islamic Studies Certificate / Course', 80),
                  ('professional_courses', 'other', 'Other', 90),
                  ('professional_courses', 'not_applicable_prefer_not_to_say', 'Not Applicable / Prefer not to say', 100),
                  ('occupation_type', 'entrepreneur_business_owner', 'Entrepreneur / Business Owner', 10),
                  ('occupation_type', 'homemaker', 'Homemaker', 20),
                  ('occupation_type', 'not_applicable_prefer_not_to_say', 'Not Applicable / Prefer not to say', 30),
                  ('occupation_type', 'retired', 'Retired', 40),
                  ('occupation_type', 'salaried_professional', 'Salaried Professional', 50),
                  ('occupation_type', 'self_employed_professional', 'Self-Employed Professional', 60),
                  ('occupation_type', 'student_school_college', 'Student (School / College)', 70),
                  ('field_of_work', 'business_trade_commerce', 'Business / Trade / Commerce', 10),
                  ('field_of_work', 'design_architecture_creative_arts', 'Design / Architecture / Creative Arts', 20),
                  ('field_of_work', 'digital_marketing_social_media', 'Digital Marketing & Social Media', 30),
                  ('field_of_work', 'education_training', 'Education / Training', 40),
                  ('field_of_work', 'engineering_manufacturing_infrastructure', 'Engineering / Manufacturing / Infrastructure', 50),
                  ('field_of_work', 'finance_accounting_banking_insurance_investments', 'Finance / Accounting / Banking / Insurance / Investments', 60),
                  ('field_of_work', 'government_public_sector', 'Government / Public Sector', 70),
                  ('field_of_work', 'human_resources_hr_talent_l_d_people_functions', 'Human Resources (HR) / Talent / L&D / People Functions', 80),
                  ('field_of_work', 'islamic_religious_work', 'Islamic / Religious Work', 90),
                  ('field_of_work', 'it_computer_applications_ai_ml', 'IT, Computer Applications, AI / ML', 100),
                  ('field_of_work', 'law_legal_services', 'Law / Legal Services', 110),
                  ('field_of_work', 'management_consulting_general_administration', 'Management / Consulting / General Administration', 120),
                  ('field_of_work', 'media_communication', 'Media & Communication', 130),
                  ('field_of_work', 'medicine_healthcare_pharma', 'Medicine / Healthcare / Pharma', 140),
                  ('field_of_work', 'not_applicable_prefer_not_to_say', 'Not Applicable / Prefer not to say', 150),
                  ('field_of_work', 'sales_and_marketing_traditional_offline', 'Sales and Marketing (Traditional / Offline)', 160),
                  ('field_of_work', 'social_work_community_services', 'Social Work / Community Services', 170),
                  ('field_of_work', 'translation_services', 'Translation Services', 180),
                  ('years_experience', '0_1_year', '0-1 year', 10),
                  ('years_experience', '1_3_years', '1-3 years', 20),
                  ('years_experience', '3_5_years', '3-5 years', 30),
                  ('years_experience', '5_8_years', '5-8 years', 40),
                  ('years_experience', '8_12_years', '8-12 years', 50),
                  ('years_experience', '12_years', '12+ years', 60),
                  ('years_experience', 'not_applicable_prefer_not_to_say', 'Not Applicable / Prefer not to say', 70),
                  ('role_level', 'early_career_junior_level_intern_trainee_associate_executive', 'Early Career / Junior Level (Intern, Trainee, Associate, Executive)', 10),
                  ('role_level', 'mid_managerial_level_senior_executive_analyst_specialist_am_dm_manager', 'Mid / Managerial Level (Senior Executive, Analyst, Specialist, AM, DM, Manager)', 20),
                  ('role_level', 'senior_professional_leader_level_senior_manager_avp_agm_team_lead_supervisor', 'Senior Professional / Leader Level (Senior Manager, AVP, AGM, Team Lead, Supervisor)', 30),
                  ('role_level', 'leadership_level_director_head_vp_gm', 'Leadership Level (Director, Head, VP, GM)', 40),
                  ('role_level', 'cxo_level_ceo_coo_cto_chro_cfo', 'CXO Level (CEO, COO, CTO, CHRO, CFO)', 50),
                  ('role_level', 'business_owner_founder_co_founder', 'Business Owner / Founder / Co-founder', 60),
                  ('role_level', 'not_applicable_prefer_not_to_say', 'Not Applicable / Prefer not to say', 70);
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("delete from platform.lookups where type in ('education', 'field_of_study', 'professional_courses', 'occupation_type', 'field_of_work', 'years_experience', 'role_level')");
        }
    }
}
