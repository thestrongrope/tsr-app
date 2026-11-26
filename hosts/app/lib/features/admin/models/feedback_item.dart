import '../../../core/utils/api_datetime.dart';

// A submitted feedback item in the reviewer queue (#891, #892, #893).

class FeedbackSender {
  const FeedbackSender({required this.name, this.token});

  final String name;
  final int? token;

  bool get isFormerMember => token == null;

  /// Returns "Name (token)" for active members, or "Former member" when token is null.
  String get displayName => token != null ? '$name ($token)' : name;

  factory FeedbackSender.fromJson(Map<String, dynamic> json) {
    return FeedbackSender(
      name: json['name'] as String? ?? 'Former member',
      token: json['token'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'token': token};
}

class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.sender,
    required this.isHandled,
    this.handledAt,
    this.handledBy,
  });

  final int id;
  final String text;
  final DateTime createdAt;
  final FeedbackSender sender;
  final bool isHandled;
  final DateTime? handledAt;
  final int? handledBy;

  FeedbackItem copyWith({
    int? id,
    String? text,
    DateTime? createdAt,
    FeedbackSender? sender,
    bool? isHandled,
    DateTime? handledAt,
    int? handledBy,
    bool clearHandled = false,
  }) {
    return FeedbackItem(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      sender: sender ?? this.sender,
      isHandled: isHandled ?? this.isHandled,
      handledAt: clearHandled ? null : handledAt ?? this.handledAt,
      handledBy: clearHandled ? null : handledBy ?? this.handledBy,
    );
  }

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    final senderJson = json['sender'] as Map<String, dynamic>? ?? {};
    final createdAtRaw = json['createdAt'] as String?;
    final handledAtRaw = json['handledAt'] as String?;

    return FeedbackItem(
      id: json['id'] as int,
      text: json['text'] as String? ?? '',
      createdAt: parseApiDateTime(createdAtRaw) ?? DateTime.now(),
      sender: FeedbackSender.fromJson(senderJson),
      isHandled: json['isHandled'] as bool? ?? false,
      handledAt: parseApiDateTime(handledAtRaw),
      handledBy: json['handledBy'] as int?,
    );
  }
}

/// One page of the queue as the server sends it, with the size of the whole queue.
class FeedbackPage {
  const FeedbackPage({
    required this.items,
    required this.unhandledCount,
    required this.handledCount,
    required this.page,
    required this.pageSize,
  });

  final List<FeedbackItem> items;
  final int unhandledCount;
  final int handledCount;
  final int page;
  final int pageSize;

  factory FeedbackPage.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['items'] is! List ||
        json['counts'] is! Map<String, dynamic>) {
      throw const FormatException('Unexpected feedback response');
    }
    final counts = json['counts'] as Map<String, dynamic>;
    return FeedbackPage(
      items: (json['items'] as List)
          .map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      unhandledCount: counts['unhandled'] as int? ?? 0,
      handledCount: counts['handled'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 50,
    );
  }
}

/// The queue the screen shows: the pages loaded so far and the server's totals.
class FeedbackQueue {
  const FeedbackQueue({
    required this.items,
    required this.unhandledCount,
    required this.handledCount,
    required this.page,
    required this.pageSize,
  });

  final List<FeedbackItem> items;
  final int unhandledCount;
  final int handledCount;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < unhandledCount + handledCount;

  FeedbackQueue copyWith({
    List<FeedbackItem>? items,
    int? unhandledCount,
    int? handledCount,
    int? page,
  }) {
    return FeedbackQueue(
      items: items ?? this.items,
      unhandledCount: unhandledCount ?? this.unhandledCount,
      handledCount: handledCount ?? this.handledCount,
      page: page ?? this.page,
      pageSize: pageSize,
    );
  }
}
