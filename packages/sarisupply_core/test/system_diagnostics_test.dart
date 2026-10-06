import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_core/sarisupply_core.dart';

void main() {
  group('SystemDiagnosticsService', () {
    test('evaluateOutboxHealth categorizes queue depths correctly', () {
      final clean = SystemDiagnosticsService.evaluateOutboxHealth(0);
      expect(clean.level, HealthLevel.healthy);
      expect(
          SystemDiagnosticsService.evaluateOutboxHealth(1, blockedCount: 1)
              .level,
          HealthLevel.warning);

      final normal = SystemDiagnosticsService.evaluateOutboxHealth(12);
      expect(normal.level, HealthLevel.healthy);

      final warning = SystemDiagnosticsService.evaluateOutboxHealth(45);
      expect(warning.level, HealthLevel.warning);

      final critical = SystemDiagnosticsService.evaluateOutboxHealth(150);
      expect(critical.level, HealthLevel.critical);
    });

    test('evaluateClockDrift detects acceptable and severe time drift', () {
      final now = DateTime.now();

      final inSync = SystemDiagnosticsService.evaluateClockDrift(
        deviceTime: now,
        referenceTime: now.subtract(const Duration(seconds: 45)),
      );
      expect(inSync.level, HealthLevel.healthy);

      final offset = SystemDiagnosticsService.evaluateClockDrift(
        deviceTime: now,
        referenceTime: now.subtract(const Duration(seconds: 180)),
      );
      expect(offset.level, HealthLevel.warning);

      final severe = SystemDiagnosticsService.evaluateClockDrift(
        deviceTime: now,
        referenceTime: now.subtract(const Duration(seconds: 600)),
      );
      expect(severe.level, HealthLevel.critical);
    });

    test('evaluateDatabaseIntegrity translates SQLite status', () {
      final healthy = SystemDiagnosticsService.evaluateDatabaseIntegrity(
        isHealthy: true,
        resultMessage: 'ok',
        recordCount: 250,
      );
      expect(healthy.level, HealthLevel.healthy);

      final corrupted = SystemDiagnosticsService.evaluateDatabaseIntegrity(
        isHealthy: false,
        resultMessage: 'Page 40 broken',
        recordCount: 250,
      );
      expect(corrupted.level, HealthLevel.critical);
    });

    test('generateReport determines overall health level and summary', () {
      final m1 = SystemDiagnosticsService.evaluateOutboxHealth(0);
      final m2 = SystemDiagnosticsService.evaluateDatabaseIntegrity(
        isHealthy: true,
        resultMessage: 'ok',
        recordCount: 50,
      );
      final reportHealthy = SystemDiagnosticsService.generateReport(
        metrics: [m1, m2],
      );
      expect(reportHealthy.overallLevel, HealthLevel.healthy);

      final mWarning = SystemDiagnosticsService.evaluateOutboxHealth(50);
      final reportWarning = SystemDiagnosticsService.generateReport(
        metrics: [mWarning, m2],
      );
      expect(reportWarning.overallLevel, HealthLevel.warning);

      final mCritical = SystemDiagnosticsService.evaluateDatabaseIntegrity(
        isHealthy: false,
        resultMessage: 'corrupted',
        recordCount: 50,
      );
      final reportCritical = SystemDiagnosticsService.generateReport(
        metrics: [mWarning, mCritical],
      );
      expect(reportCritical.overallLevel, HealthLevel.critical);
    });
  });
}
