enum HealthLevel { healthy, warning, critical }

class DiagnosticMetric {
  const DiagnosticMetric({
    required this.name,
    required this.value,
    required this.level,
    required this.detail,
  });

  final String name;
  final String value;
  final HealthLevel level;
  final String detail;

  Map<String, dynamic> toMap() => {
        'name': name,
        'value': value,
        'level': level.name,
        'detail': detail,
      };

  factory DiagnosticMetric.fromMap(Map<String, dynamic> map) =>
      DiagnosticMetric(
        name: map['name'] as String? ?? '',
        value: map['value'] as String? ?? '',
        level: HealthLevel.values.firstWhere(
          (e) => e.name == map['level'],
          orElse: () => HealthLevel.healthy,
        ),
        detail: map['detail'] as String? ?? '',
      );
}

class SystemDiagnosticsReport {
  const SystemDiagnosticsReport({
    required this.overallLevel,
    required this.evaluatedAt,
    required this.metrics,
    required this.summary,
  });

  final HealthLevel overallLevel;
  final DateTime evaluatedAt;
  final List<DiagnosticMetric> metrics;
  final String summary;

  Map<String, dynamic> toMap() => {
        'overallLevel': overallLevel.name,
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'metrics': metrics.map((m) => m.toMap()).toList(),
        'summary': summary,
      };

  factory SystemDiagnosticsReport.fromMap(Map<String, dynamic> map) =>
      SystemDiagnosticsReport(
        overallLevel: HealthLevel.values.firstWhere(
          (e) => e.name == map['overallLevel'],
          orElse: () => HealthLevel.healthy,
        ),
        evaluatedAt: DateTime.tryParse(map['evaluatedAt'] as String? ?? '') ??
            DateTime.now(),
        metrics: (map['metrics'] as List? ?? [])
            .map((m) =>
                DiagnosticMetric.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList(),
        summary: map['summary'] as String? ?? '',
      );
}

class SystemDiagnosticsService {
  /// Evaluates outbox pending backlog health.
  static DiagnosticMetric evaluateOutboxHealth(int pendingCount,
      {int blockedCount = 0}) {
    if (blockedCount > 0) {
      return DiagnosticMetric(
          name: 'Local operation queues',
          value: '$blockedCount need review',
          level: HealthLevel.warning,
          detail:
              'Blocked or conflicting operations are retained. Review them before retrying.');
    }
    if (pendingCount == 0) {
      return const DiagnosticMetric(
        name: 'Sync Outbox Queue',
        value: '0 pending',
        level: HealthLevel.healthy,
        detail: 'No pending or blocked local operations were found.',
      );
    } else if (pendingCount < 20) {
      return DiagnosticMetric(
        name: 'Sync Outbox Queue',
        value: '$pendingCount pending',
        level: HealthLevel.healthy,
        detail: 'Local operations are waiting for synchronization.',
      );
    } else if (pendingCount < 100) {
      return DiagnosticMetric(
        name: 'Sync Outbox Queue',
        value: '$pendingCount pending',
        level: HealthLevel.warning,
        detail:
            'Elevated outbox queue depth. Connect to internet to sync changes.',
      );
    } else {
      return DiagnosticMetric(
        name: 'Sync Outbox Queue',
        value: '$pendingCount pending',
        level: HealthLevel.critical,
        detail:
            'Heavy outbox backlog. Sync urgently to avoid storage congestion.',
      );
    }
  }

  /// Evaluates monotonic wall clock drift against a reference time.
  static DiagnosticMetric evaluateClockDrift({
    required DateTime deviceTime,
    required DateTime referenceTime,
  }) {
    final diff = deviceTime.difference(referenceTime).inSeconds.abs();
    if (diff < 120) {
      return DiagnosticMetric(
        name: 'Monotonic Clock Drift',
        value: '${diff}s offset',
        level: HealthLevel.healthy,
        detail: 'Device clock is closely synchronized with trusted reference.',
      );
    } else if (diff < 300) {
      return DiagnosticMetric(
        name: 'Monotonic Clock Drift',
        value: '${diff}s offset',
        level: HealthLevel.warning,
        detail:
            'Moderate clock offset detected. May cause brief authorization warnings.',
      );
    } else {
      return DiagnosticMetric(
        name: 'Monotonic Clock Drift',
        value: '${diff}s offset',
        level: HealthLevel.critical,
        detail:
            'Severe clock drift detected. Offline token authorization may fail.',
      );
    }
  }

  /// Evaluates SQLite database integrity check result.
  static DiagnosticMetric evaluateDatabaseIntegrity({
    required bool isHealthy,
    required String resultMessage,
    required int recordCount,
  }) {
    if (isHealthy) {
      return DiagnosticMetric(
        name: 'SQLite Database Integrity',
        value: 'Healthy (PRAGMA OK)',
        level: HealthLevel.healthy,
        detail:
            'B-tree index and page consistency confirmed across $recordCount records.',
      );
    } else {
      return DiagnosticMetric(
        name: 'SQLite Database Integrity',
        value: 'CORRUPTED: $resultMessage',
        level: HealthLevel.critical,
        detail:
            'Database corruption detected! Restore from encrypted backup immediately.',
      );
    }
  }

  /// Consolidates diagnostics into an overall system health report.
  static SystemDiagnosticsReport generateReport({
    required List<DiagnosticMetric> metrics,
    DateTime? now,
  }) {
    final evaluatedAt = now ?? DateTime.now();
    var overall = HealthLevel.healthy;

    for (final m in metrics) {
      if (m.level == HealthLevel.critical) {
        overall = HealthLevel.critical;
        break;
      } else if (m.level == HealthLevel.warning &&
          overall != HealthLevel.critical) {
        overall = HealthLevel.warning;
      }
    }

    final summary = switch (overall) {
      HealthLevel.healthy => 'All core systems operating normally offline.',
      HealthLevel.warning =>
        'One or more systems require attention or reconnection.',
      HealthLevel.critical =>
        'Critical system fault detected! Take corrective action.',
    };

    return SystemDiagnosticsReport(
      overallLevel: overall,
      evaluatedAt: evaluatedAt,
      metrics: metrics,
      summary: summary,
    );
  }
}
