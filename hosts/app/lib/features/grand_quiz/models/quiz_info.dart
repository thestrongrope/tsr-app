import 'package:flutter/material.dart';

/// Main quiz info model: the body of `GET /quiz/info`
class QuizInfo {
  final String type; // 'mega' or 'grand'
  final String name;
  final String series;
  final String description;
  final String status; // 'offline', 'upcoming', 'registered', 'live', 'ended'
  final String message;
  final bool isSuperuser;
  final QuizTiming timing;
  final QuizEpisodes? episodes;
  final String? banner;
  final QuizColors colors;
  final String mode;
  final String? youtubeUrl;
  final String? adminUrl;
  final QuizAuth auth;

  /// False when the draw's rules leave this member out (their country or
  /// token is excluded). The card then hides sign-up and says so (#868).
  final bool canTakePart;

  const QuizInfo({
    required this.type,
    required this.name,
    required this.series,
    required this.description,
    required this.status,
    required this.message,
    required this.isSuperuser,
    required this.timing,
    this.episodes,
    this.banner,
    required this.colors,
    required this.mode,
    this.youtubeUrl,
    this.adminUrl,
    required this.auth,
    this.canTakePart = true,
  });

  factory QuizInfo.fromJson(Map<String, dynamic> json) {
    return QuizInfo(
      type: json['type'] as String? ?? 'grand',
      name: json['name'] as String? ?? '',
      series: json['series'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      message: json['message'] as String? ?? '',
      isSuperuser: json['is_superuser'] as bool? ?? false,
      timing: QuizTiming.fromJson(
        json['timing'] as Map<String, dynamic>? ?? {},
      ),
      episodes: json['episodes'] != null
          ? QuizEpisodes.fromJson(json['episodes'] as Map<String, dynamic>)
          : null,
      banner: json['banner'] as String?,
      colors: QuizColors.fromJson(
        json['colors'] as Map<String, dynamic>? ?? {},
      ),
      mode: json['mode'] as String? ?? 'Live',
      youtubeUrl: json['youtube_url'] as String?,
      adminUrl: json['admin_url'] as String?,
      auth: QuizAuth.fromJson(json['auth'] as Map<String, dynamic>? ?? {}),
      canTakePart: json['can_take_part'] as bool? ?? true,
    );
  }

  /// Check if the quiz is a mega quiz with multiple episodes
  bool get isMegaQuiz => type.toLowerCase() == 'mega';

  /// Check if the quiz is a grand quiz (single episode)
  bool get isGrandQuiz => type.toLowerCase() == 'grand';

  /// Check if the quiz is currently active (not offline or ended)
  bool get isActive => status != 'offline' && status != 'ended';

  /// Banner visibility rule:
  /// - Hide when offline
  /// - Keep ended quiz visible for 2 days, then hide
  bool get shouldDisplayBanner {
    if (status == 'offline') return false;
    if (status != 'ended') return true;

    final endTime = _effectiveQuizEnd;
    if (endTime == null) return false;
    return DateTime.now().difference(endTime) <= const Duration(days: 2);
  }

  DateTime? get _effectiveQuizEnd {
    if (timing.quizStop != null) return timing.quizStop;
    if (episodes == null || episodes!.list.isEmpty) return null;
    final episodeEnds = episodes!.list
        .map((e) => e.end)
        .whereType<DateTime>()
        .toList();
    if (episodeEnds.isEmpty) return null;
    episodeEnds.sort();
    return episodeEnds.last;
  }

  /// Check if user is registered for this quiz
  bool get isRegistered => status == 'registered';

  /// Check if the quiz is currently live
  bool get isLive => status == 'live';

  /// Check if the quiz is upcoming
  bool get isUpcoming => status == 'upcoming';

  /// Get the current or next episode for mega quizzes
  QuizEpisode? get currentOrNextEpisode {
    if (episodes == null) return null;
    if (episodes!.currentEpisode != null) {
      return episodes!.list.firstWhere(
        (e) => e.number == episodes!.currentEpisode,
        orElse: () => episodes!.list.first,
      );
    }
    if (episodes!.nextEpisode != null) {
      return episodes!.list.firstWhere(
        (e) => e.number == episodes!.nextEpisode,
        orElse: () => episodes!.list.first,
      );
    }
    return episodes!.list.isNotEmpty ? episodes!.list.first : null;
  }
}

/// Quiz timing information
class QuizTiming {
  final DateTime? registrationStart;
  final DateTime? quizStop;

  const QuizTiming({this.registrationStart, this.quizStop});

  factory QuizTiming.fromJson(Map<String, dynamic> json) {
    return QuizTiming(
      registrationStart: json['registration_start'] != null
          ? DateTime.tryParse(json['registration_start'] as String)
          : null,
      quizStop: json['quiz_stop'] != null
          ? DateTime.tryParse(json['quiz_stop'] as String)
          : null,
    );
  }

  /// Check if registration is open
  bool get isRegistrationOpen {
    if (registrationStart == null) return false;
    final now = DateTime.now();
    return now.isAfter(registrationStart!) &&
        (quizStop == null || now.isBefore(quizStop!));
  }

  /// Time remaining until quiz ends
  Duration? get timeRemaining {
    if (quizStop == null) return null;
    final remaining = quizStop!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Episodes data for mega quizzes
class QuizEpisodes {
  final int total;
  final int currentDay;
  final int? currentEpisode;
  final int? nextEpisode;
  final List<QuizEpisode> list;

  const QuizEpisodes({
    required this.total,
    required this.currentDay,
    this.currentEpisode,
    this.nextEpisode,
    required this.list,
  });

  factory QuizEpisodes.fromJson(Map<String, dynamic> json) {
    return QuizEpisodes(
      total: json['total'] as int? ?? 0,
      currentDay: json['current_day'] as int? ?? 0,
      currentEpisode: json['current_episode'] as int?,
      nextEpisode: json['next_episode'] as int?,
      list:
          (json['list'] as List<dynamic>?)
              ?.map((e) => QuizEpisode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Get completed episodes count
  int get completedCount => list.where((e) => e.status == 'ended').length;

  /// Get live episodes count
  int get liveCount => list.where((e) => e.status == 'live').length;

  /// Progress percentage (0.0 to 1.0)
  double get progress => total > 0 ? completedCount / total : 0.0;
}

/// Individual episode data
class QuizEpisode {
  final int id;
  final int number;
  final String status; // 'upcoming', 'live', 'ended'
  final bool isAccessible;
  final DateTime? start;
  final DateTime? end;
  final EpisodeParticipation? participation;
  final String? formId;

  const QuizEpisode({
    required this.id,
    required this.number,
    required this.status,
    required this.isAccessible,
    this.start,
    this.end,
    this.participation,
    this.formId,
  });

  factory QuizEpisode.fromJson(Map<String, dynamic> json) {
    return QuizEpisode(
      id: json['id'] as int? ?? 0,
      number: json['number'] as int? ?? 0,
      status: json['status'] as String? ?? 'upcoming',
      isAccessible: json['is_accessible'] as bool? ?? false,
      start: json['start'] != null
          ? DateTime.tryParse(json['start'] as String)
          : null,
      end: json['end'] != null
          ? DateTime.tryParse(json['end'] as String)
          : null,
      participation: json['participation'] != null
          ? EpisodeParticipation.fromJson(
              json['participation'] as Map<String, dynamic>,
            )
          : null,
      formId: json['form_id'] as String?,
    );
  }

  /// Check if episode is currently live
  bool get isLive => status == 'live';

  /// Check if episode has ended
  bool get isEnded => status == 'ended';

  /// Check if episode is upcoming
  bool get isUpcoming => status == 'upcoming';

  /// Duration of the episode
  Duration? get duration {
    if (start == null || end == null) return null;
    return end!.difference(start!);
  }

  /// Time until episode starts
  Duration? get timeUntilStart {
    if (start == null) return null;
    final remaining = start!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Participation data for an episode
class EpisodeParticipation {
  final String? formId;
  final String? formBaseUrl;
  final ParticipationUserData? userData;

  const EpisodeParticipation({this.formId, this.formBaseUrl, this.userData});

  factory EpisodeParticipation.fromJson(Map<String, dynamic> json) {
    return EpisodeParticipation(
      formId: json['form_id'] as String?,
      formBaseUrl: json['form_base_url'] as String?,
      userData: json['user_data'] != null
          ? ParticipationUserData.fromJson(
              json['user_data'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// User data for participation form pre-fill
class ParticipationUserData {
  final String? email;
  final String? token;
  final String? name;
  final String? city;
  final String? mobile;

  const ParticipationUserData({
    this.email,
    this.token,
    this.name,
    this.city,
    this.mobile,
  });

  factory ParticipationUserData.fromJson(Map<String, dynamic> json) {
    return ParticipationUserData(
      email: json['email'] as String?,
      token: json['token']?.toString(),
      name: json['name'] as String?,
      city: json['city'] as String?,
      mobile: json['mobile'] as String?,
    );
  }
}

/// Quiz branding colors from API
class QuizColors {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color text;

  const QuizColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.text,
  });

  factory QuizColors.fromJson(Map<String, dynamic> json) {
    return QuizColors(
      primary: _parseColor(json['primary'] as String?, const Color(0xFFAE3242)),
      secondary: _parseColor(
        json['secondary'] as String?,
        const Color(0xFF510D25),
      ),
      background: _parseColor(json['background'] as String?, Colors.white),
      text: _parseColor(json['text'] as String?, Colors.black),
    );
  }

  static Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      String cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 3) {
        cleanHex = cleanHex.split('').map((c) => '$c$c').join();
      }
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  /// Create gradient from primary to secondary
  LinearGradient get gradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Create a darker version of primary for shadows
  Color get primaryDark =>
      Color.alphaBlend(Colors.black.withValues(alpha: 0.3), primary);
}

/// Authentication info from API
class QuizAuth {
  final String method; // 'none', 'token', 'firebase', 'firebase+token'
  final bool canRegister;
  final int? userToken;

  const QuizAuth({
    required this.method,
    required this.canRegister,
    this.userToken,
  });

  factory QuizAuth.fromJson(Map<String, dynamic> json) {
    return QuizAuth(
      method: json['method'] as String? ?? 'none',
      canRegister: json['can_register'] as bool? ?? false,
      userToken: json['user_token'] as int?,
    );
  }

  /// Check if fully authenticated with dual auth
  bool get isFullyAuthenticated => method == 'firebase+token';

  /// Check if any authentication is present
  bool get isAuthenticated => method != 'none';
}

/// API Response wrapper
class QuizInfoResponse {
  final bool success;
  final QuizInfo? data;
  final String? error;

  const QuizInfoResponse({required this.success, this.data, this.error});

  factory QuizInfoResponse.fromJson(Map<String, dynamic> json) {
    return QuizInfoResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null
          ? QuizInfo.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }
}
