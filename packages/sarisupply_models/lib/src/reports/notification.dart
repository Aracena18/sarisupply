enum NotificationCategory {
  stock,
  expiry,
  delivery,
  shift,
  sync;

  String get label {
    switch (this) {
      case NotificationCategory.stock:
        return 'Stock Alert';
      case NotificationCategory.expiry:
        return 'Expiry Warning';
      case NotificationCategory.delivery:
        return 'Delivery Update';
      case NotificationCategory.shift:
        return 'Shift Notice';
      case NotificationCategory.sync:
        return 'Sync Status';
    }
  }

  static NotificationCategory fromString(String val) {
    for (final c in NotificationCategory.values) {
      if (c.name == val) return c;
    }
    return NotificationCategory.stock;
  }
}

enum NotificationSeverity {
  info,
  warning,
  critical;

  static NotificationSeverity fromString(String val) {
    for (final s in NotificationSeverity.values) {
      if (s.name == val) return s;
    }
    return NotificationSeverity.info;
  }
}

class SariNotification {
  const SariNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.createdAt,
    this.isRead = false,
    this.actionPayload = const {},
  });

  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final NotificationSeverity severity;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> actionPayload;

  SariNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationCategory? category,
    NotificationSeverity? severity,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? actionPayload,
  }) =>
      SariNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        category: category ?? this.category,
        severity: severity ?? this.severity,
        createdAt: createdAt ?? this.createdAt,
        isRead: isRead ?? this.isRead,
        actionPayload: actionPayload ?? this.actionPayload,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'category': category.name,
        'severity': severity.name,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'actionPayload': actionPayload,
      };

  factory SariNotification.fromMap(Map<String, dynamic> map) =>
      SariNotification(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        message: map['message'] as String? ?? '',
        category:
            NotificationCategory.fromString(map['category'] as String? ?? ''),
        severity:
            NotificationSeverity.fromString(map['severity'] as String? ?? ''),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        isRead: map['isRead'] is bool
            ? (map['isRead'] as bool)
            : (map['isRead'] == 1),
        actionPayload:
            Map<String, dynamic>.from(map['actionPayload'] as Map? ?? {}),
      );
}
