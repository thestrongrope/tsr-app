namespace Tsr.Classes.Api;

// One class per PHP table of this domain, columns in PHP's order. A reference to a member, gender, language or another domain's row
// is a plain integer. "token" is PHP's member token (users.token), not the identity user id.

/// <summary>A class (PHP <c>classes</c>). <c>Gender</c> is a platform gender id, <c>Teacher</c> a member token. Status 'A' is active.</summary>
internal sealed class ClassRow
{
    public int Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public int? LanguageId { get; set; }

    public string? Link { get; set; }

    public string Name { get; set; } = string.Empty;

    public int? ClassLevelId { get; set; }

    public DateOnly? StartedOn { get; set; }

    public int? Teacher { get; set; }

    public int? Gender { get; set; }

    public string Format { get; set; } = "Offline";

    public string? Address { get; set; }

    public string? City { get; set; }

    public string? Country { get; set; }

    public decimal? Lat { get; set; }

    public decimal? Lng { get; set; }

    public string? Location { get; set; }

    public string? ExtraStudents { get; set; }

    public string Status { get; set; } = "A";

    public DateOnly? ShutdownOn { get; set; }

    public DateOnly? CompletedOn { get; set; }

    public string? Comments { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? CreatedBy { get; set; }

    public int? UpdatedBy { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>A level of the curriculum (PHP <c>class_levels</c>).</summary>
internal sealed class ClassLevel
{
    public int Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public int SortOrder { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>A label a class can carry (PHP <c>tags</c>).</summary>
internal sealed class Tag
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? CreatedBy { get; set; }

    public int? UpdatedBy { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>A tag on a class (PHP <c>class_tags</c>, key: class and tag).</summary>
internal sealed class ClassTag
{
    public int ClassId { get; set; }

    public int TagId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? CreatedBy { get; set; }

    public int? UpdatedBy { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>A weekly slot of a class (PHP <c>class_schedules</c>): weekday number, hour and minute, read in <c>Timezone</c>.</summary>
internal sealed class ClassSchedule
{
    public int Id { get; set; }

    public int ClassId { get; set; }

    public int? Day { get; set; }

    public int? Hour { get; set; }

    public int? Minute { get; set; }

    public string? Timezone { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }

    public int? UpdatedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>A subject area of the teaching plan (PHP <c>topics</c>).</summary>
internal sealed class Topic
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public int IsVocational { get; set; }

    public int? SortOrder { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset? ModifiedAt { get; set; }

    public int? ModifiedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>A topic planned for a schedule slot (PHP <c>class_schedule_topics</c>).</summary>
internal sealed class ClassScheduleTopic
{
    public int Id { get; set; }

    public int ClassScheduleId { get; set; }

    public int? TopicId { get; set; }

    public int? SortOrder { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }

    public int? UpdatedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>
/// One held (or missed) session of a class (PHP <c>class_sessions</c>). <c>ConductedOn</c> is the calendar day the class met, a wall-clock
/// day, so it is a <c>date</c>. The five <c>*Conducted</c> columns are PHP's 'Y'/'N' flags, kept as text. <c>Teacher</c> is a member token.
/// </summary>
internal sealed class ClassSession
{
    public int Id { get; set; }

    public int? ClassId { get; set; }

    public int Teacher { get; set; }

    public DateOnly ConductedOn { get; set; }

    public short Conducted { get; set; } = 1;

    public string? NonConductionReason { get; set; }

    public int? ConductedBy { get; set; }

    public int? Duration { get; set; }

    public int? Attendance { get; set; }

    public int? QuranRecitationSurah { get; set; }

    public int? QuranRecitationVerse { get; set; }

    public string ArabicConducted { get; set; } = "N";

    public string? ArabicTopic { get; set; }

    public string AqaedConducted { get; set; } = "Y";

    public string? AqaedTopic { get; set; }

    public string AhkamConducted { get; set; } = "N";

    public string? AhkamTopic { get; set; }

    public string AkhlaqConducted { get; set; } = "N";

    public string? AkhlaqTopic { get; set; }

    public string OtherConducted { get; set; } = "N";

    public string? OtherTopic { get; set; }

    public string? Assignments { get; set; }

    public int AssignmentCount { get; set; }

    public string? TeamRequest { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }

    public int? UpdatedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>One student's attendance at one session (PHP <c>class_attendance</c>). <c>Present</c> and <c>ExtraStudent</c> are PHP's tinyint flags.</summary>
internal sealed class ClassAttendance
{
    public int Id { get; set; }

    public int SessionId { get; set; }

    public int Token { get; set; }

    public string? Name { get; set; }

    public short ExtraStudent { get; set; }

    public short Present { get; set; }

    public int Recitation { get; set; }

    public int PagesRead { get; set; }

    public float AssignmentsDone { get; set; }

    public string? Followup { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>A member's enrolment in a class (PHP <c>class_students</c>). Status 'A' is active. <c>TokenNo</c> is the member token.</summary>
internal sealed class ClassStudent
{
    public int Id { get; set; }

    public int? ClassId { get; set; }

    public int? TokenNo { get; set; }

    public DateOnly? JoinedOn { get; set; }

    public short? DataAdmin { get; set; }

    public short? McqAdmin { get; set; }

    public short? AssignmentAdmin { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? RemovedAt { get; set; }

    public string? RemovedReason { get; set; }

    public int? RemovedBy { get; set; }

    public string Status { get; set; } = "A";

    public string? Notes { get; set; }

    public int? AddedBy { get; set; }
}

/// <summary>A student moved, promoted or demoted between classes (PHP <c>student_transfers</c>).</summary>
internal sealed class StudentTransfer
{
    public int Id { get; set; }

    public int TokenNo { get; set; }

    public int FromClassId { get; set; }

    public int ToClassId { get; set; }

    public string Type { get; set; } = "transfer";

    public string? Reason { get; set; }

    public int TransferredBy { get; set; }

    public DateTimeOffset TransferredAt { get; set; }
}

/// <summary>An entry of the class audit trail (PHP <c>class_audit_log</c>). <c>Details</c> is JSON kept as text.</summary>
internal sealed class ClassAuditEntry
{
    public long Id { get; set; }

    public int ClassId { get; set; }

    public string Action { get; set; } = string.Empty;

    public string? Details { get; set; }

    public int PerformedBy { get; set; }

    public DateTimeOffset PerformedAt { get; set; }
}

/// <summary>A teacher's training record by member token (PHP <c>teachers</c>): the five levels each have a column.</summary>
internal sealed class Teacher
{
    public int Token { get; set; }

    public int Salman { get; set; }

    public int Abuzar { get; set; }

    public int Miqdad { get; set; }

    public int Ammar { get; set; }

    public int Bilal { get; set; }

    public string? Comments { get; set; }

    public string Status { get; set; } = string.Empty;

    public int? CreatedBy { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? UpdatedBy { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }

    public int? DeletedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }
}

/// <summary>A past state of a teacher record (PHP <c>teachers_history</c>).</summary>
internal sealed class TeacherHistory
{
    public int Id { get; set; }

    public int? Token { get; set; }

    public int Salman { get; set; }

    public int Abuzar { get; set; }

    public int Miqdad { get; set; }

    public int Ammar { get; set; }

    public int Bilal { get; set; }

    public string? Comments { get; set; }

    public string? Status { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>A syllabus link for a level (PHP <c>syllabus</c>): a pdf or an external page.</summary>
internal sealed class SyllabusEntry
{
    public int Id { get; set; }

    public int LevelId { get; set; }

    public string SubjectName { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string LinkType { get; set; } = "pdf";

    public string Url { get; set; } = string.Empty;

    public int? SortOrder { get; set; }

    public short IsActive { get; set; } = 1;

    public DateTimeOffset CreatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset? ModifiedAt { get; set; }

    public int? ModifiedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>The teacher's guide for a level in a language (PHP <c>guides</c>).</summary>
internal sealed class Guide
{
    public int Id { get; set; }

    public int LevelId { get; set; }

    public int LanguageId { get; set; }

    public string? Text { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int CreatedBy { get; set; }

    public int? UpdatedBy { get; set; }

    public int? DeletedBy { get; set; }
}
