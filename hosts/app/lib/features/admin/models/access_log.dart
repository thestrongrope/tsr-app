/// Who used the admin pages, in the last 30 days (#419).
class AccessLogUser {
  final int token;
  final String name;
  final String email;
  final int hits;
  final int activeDays;
  final String lastAccessed;

  const AccessLogUser({
    required this.token,
    required this.name,
    required this.email,
    required this.hits,
    required this.activeDays,
    required this.lastAccessed,
  });

  factory AccessLogUser.fromJson(Map<String, dynamic> json) => AccessLogUser(
    token: json['token'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    hits: json['hits'] as int,
    activeDays: json['activeDays'] as int,
    lastAccessed: json['lastAccessed'] as String? ?? '',
  );
}

/// How much an admin page was used, in the last 30 days.
class AccessLogPage {
  final String page;
  final int hits;
  final String lastAccessed;

  const AccessLogPage({
    required this.page,
    required this.hits,
    required this.lastAccessed,
  });

  factory AccessLogPage.fromJson(Map<String, dynamic> json) => AccessLogPage(
    page: json['page'] as String,
    hits: json['hits'] as int,
    lastAccessed: json['lastAccessed'] as String? ?? '',
  );
}

/// One access. [name] and [email] are empty for a user who is gone.
class AccessLogEntry {
  final int id;
  final String accessedAt;
  final int token;
  final String name;
  final String email;
  final String role;
  final String method;
  final String page;
  final String ip;

  const AccessLogEntry({
    required this.id,
    required this.accessedAt,
    required this.token,
    required this.name,
    required this.email,
    required this.role,
    required this.method,
    required this.page,
    required this.ip,
  });

  factory AccessLogEntry.fromJson(Map<String, dynamic> json) => AccessLogEntry(
    id: json['id'] as int,
    accessedAt: json['accessedAt'] as String? ?? '',
    token: json['token'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? '',
    method: json['method'] as String? ?? '',
    page: json['page'] as String? ?? '',
    ip: json['ip'] as String? ?? '',
  );
}

/// The three lists the server answers for one filter.
class AccessLog {
  final List<AccessLogUser> users;
  final List<AccessLogPage> pages;
  final List<AccessLogEntry> recent;

  const AccessLog({
    required this.users,
    required this.pages,
    required this.recent,
  });

  bool get isEmpty => users.isEmpty && pages.isEmpty && recent.isEmpty;

  factory AccessLog.fromJson(Map<String, dynamic> json) => AccessLog(
    users: [
      for (final u in json['users'] as List<dynamic>)
        AccessLogUser.fromJson(u as Map<String, dynamic>),
    ],
    pages: [
      for (final p in json['pages'] as List<dynamic>)
        AccessLogPage.fromJson(p as Map<String, dynamic>),
    ],
    recent: [
      for (final r in json['recent'] as List<dynamic>)
        AccessLogEntry.fromJson(r as Map<String, dynamic>),
    ],
  );
}

/// What the lists are narrowed by: one member, and part of a page name. A
/// value, so it can key the provider.
class AccessLogFilter {
  final int? token;
  final String page;

  const AccessLogFilter({this.token, this.page = ''});

  bool get isEmpty => token == null && page.isEmpty;

  AccessLogFilter copyWith({
    int? token,
    bool clearToken = false,
    String? page,
  }) => AccessLogFilter(
    token: clearToken ? null : (token ?? this.token),
    page: page ?? this.page,
  );

  @override
  bool operator ==(Object other) =>
      other is AccessLogFilter && other.token == token && other.page == page;

  @override
  int get hashCode => Object.hash(token, page);
}
