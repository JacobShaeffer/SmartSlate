#include "batteryestimator.h"
#include "batterymonitor.h"
#include "max17048.h"

#include <QTextStream>
#include <QtTest>

#include <limits>

class BatteryTest : public QObject
{
    Q_OBJECT

    void poll(BatteryMonitor &monitor)
    {
        QSignalSpy updates(&monitor, &BatteryMonitor::readingChanged);
        monitor.m_lastPoll.invalidate();
        monitor.refresh();
        QTRY_COMPARE(updates.count(), 1);
    }

private slots:
    void registerDecoding()
    {
        QCOMPARE(Max17048::registerWord(0x4e, 0x80), quint16(0x4e80));
        // 78.5%, 4.0V, and -100 CRATE counts = -20.8 percentage points/hour.
        const auto sample = Max17048::decode(0x4e80, 0xc800, 0xff9c);
        QCOMPARE(sample.percentage, 78.5);
        QCOMPARE(sample.voltage, 4.0);
        QCOMPARE(sample.rate, -20.8);
        QCOMPARE(Max17048::decode(0xffff, 0, 100).percentage, 100.0);
        QCOMPARE(Max17048::decode(0, 0, 100).rate, 20.8);
        QCOMPARE(Max17048::decode(0, 0, 0x8000).rate, -32768 * 0.208);
    }

    void waitsForConsistentDischarge()
    {
        BatteryEstimator estimator;
        QCOMPARE(estimator.remainingMinutes(), -1);
        estimator.update({78.0, 4.0, -23.4});
        QCOMPARE(estimator.remainingMinutes(), -1);
        estimator.update({78.0, 4.0, -23.4});
        QCOMPARE(estimator.remainingMinutes(), -1);
        estimator.update({78.0, 4.0, -23.4});
        QCOMPARE(estimator.remainingMinutes(), 200);
        QVERIFY(!estimator.charging());
    }

    void smoothsLoadChanges()
    {
        BatteryEstimator estimator;
        for (int i = 0; i < 3; ++i)
            estimator.update({50.0, 3.8, -10.0});
        QCOMPARE(estimator.remainingMinutes(), 300);
        estimator.update({50.0, 3.8, -30.0});
        // First load change moves the smoothed rate to -15, rather than -30.
        QCOMPARE(estimator.remainingMinutes(), 200);
        for (int i = 0; i < 30; ++i)
            estimator.update({50.0, 3.8, -30.0});
        QVERIFY(estimator.remainingMinutes() >= 100);
        QVERIFY(estimator.remainingMinutes() <= 101);
    }

    void chargingAndDischargingTransitions()
    {
        BatteryEstimator estimator;
        for (int i = 0; i < 3; ++i)
            estimator.update({50.0, 3.8, -10.0});
        QVERIFY(estimator.remainingMinutes() > 0);
        estimator.update({50.0, 3.8, 10.0});
        QCOMPARE(estimator.remainingMinutes(), -1);
        QVERIFY(!estimator.charging());
        estimator.update({50.0, 3.8, 10.0});
        estimator.update({50.0, 3.8, 10.0});
        QVERIFY(estimator.charging());
        QCOMPARE(estimator.remainingMinutes(), -1);
        estimator.update({50.0, 3.8, -10.0});
        QVERIFY(!estimator.charging());
        QCOMPARE(estimator.remainingMinutes(), -1);
        estimator.update({50.0, 3.8, -10.0});
        estimator.update({50.0, 3.8, -10.0});
        QCOMPARE(estimator.remainingMinutes(), 300);
    }

    void zeroAndNearZeroRate_data()
    {
        QTest::addColumn<double>("rate");
        QTest::newRow("zero") << 0.0;
        QTest::newRow("small-negative") << -0.208;
        QTest::newRow("negative-boundary") << -0.416;
        QTest::newRow("small-positive") << 0.208;
        QTest::newRow("positive-boundary") << 0.416;
    }

    void zeroAndNearZeroRate()
    {
        QFETCH(double, rate);
        BatteryEstimator estimator;
        for (int i = 0; i < 3; ++i)
            estimator.update({50.0, 3.8, -10.0});
        estimator.update({50.0, 3.8, rate});
        QCOMPARE(estimator.remainingMinutes(), -1);
        QVERIFY(!estimator.charging());
    }

    void emptyBattery()
    {
        BatteryEstimator estimator;
        for (int i = 0; i < 3; ++i)
            estimator.update({0.0, 3.0, -10.0});
        QCOMPARE(estimator.remainingMinutes(), 0);
    }

    void resetAndBatterySwap()
    {
        BatteryEstimator estimator;
        for (int i = 0; i < 3; ++i)
            estimator.update({50.0, 3.8, -10.0});
        estimator.reset();
        QCOMPARE(estimator.remainingMinutes(), -1);
        QVERIFY(!estimator.charging());
        estimator.update({50.0, 3.8, -10.0});
        QCOMPARE(estimator.remainingMinutes(), -1);
        estimator.update({50.0, 3.8, -10.0});
        estimator.update({50.0, 3.8, -10.0});
        QCOMPARE(estimator.remainingMinutes(), 300);
        estimator.update({95.0, 4.1, -10.0});
        QCOMPARE(estimator.remainingMinutes(), -1);
    }

    void invalidSamples()
    {
        BatteryEstimator estimator;
        for (int i = 0; i < 3; ++i)
            estimator.update({50.0, 3.8, -10.0});
        estimator.update({50.0, 3.8, std::numeric_limits<double>::quiet_NaN()});
        QCOMPARE(estimator.remainingMinutes(), -1);
        estimator.update({-1.0, 3.8, -10.0});
        QCOMPARE(estimator.remainingMinutes(), -1);
        estimator.update({101.0, 3.8, -10.0});
        QCOMPARE(estimator.remainingMinutes(), -1);
    }

    void missingDevice()
    {
        QString error;
        QVERIFY(!Max17048::read(QStringLiteral("/dev/smartslate-test-no-such-device"), error));
        QVERIFY(!error.isEmpty());
    }

    void asynchronousReadingsAndRecovery()
    {
        BatteryMonitor monitor(QCoreApplication::applicationFilePath(), QStringLiteral("sample"), nullptr);
        monitor.m_pollTimer.stop();
        QTRY_VERIFY(monitor.available());
        QCOMPARE(monitor.percentage(), 78);
        QCOMPARE(monitor.remainingMinutes(), -1);
        poll(monitor);
        poll(monitor);
        QCOMPARE(monitor.remainingMinutes(), 225);

        // Frequent Settings visits must not launch additional reads.
        QSignalSpy updates(&monitor, &BatteryMonitor::readingChanged);
        monitor.refresh();
        QTest::qWait(30);
        QCOMPARE(updates.count(), 0);

        monitor.m_device = QStringLiteral("failure");
        poll(monitor);
        QVERIFY(!monitor.available());
        QCOMPARE(monitor.percentage(), -1);
        QCOMPARE(monitor.remainingMinutes(), -1);
        monitor.m_device = QStringLiteral("sample");
        poll(monitor);
        QVERIFY(monitor.available());
        QCOMPARE(monitor.remainingMinutes(), -1);
    }

    void rejectsBrokenReaderOutput_data()
    {
        QTest::addColumn<QString>("mode");
        QTest::newRow("not-json") << QStringLiteral("malformed");
        QTest::newRow("missing-fields") << QStringLiteral("missing-fields");
        QTest::newRow("invalid-voltage") << QStringLiteral("invalid-voltage");
        QTest::newRow("reader-failed") << QStringLiteral("failure");
    }

    void rejectsBrokenReaderOutput()
    {
        QFETCH(QString, mode);
        BatteryMonitor monitor(QCoreApplication::applicationFilePath(), mode, nullptr);
        monitor.m_pollTimer.stop();
        QSignalSpy updates(&monitor, &BatteryMonitor::readingChanged);
        QTRY_COMPARE(updates.count(), 1);
        QVERIFY(!monitor.available());
        QCOMPARE(monitor.percentage(), -1);
        QCOMPARE(monitor.remainingMinutes(), -1);
    }

    void timeoutAndRetry()
    {
        BatteryMonitor monitor(QCoreApplication::applicationFilePath(), QStringLiteral("hang"), nullptr);
        monitor.m_pollTimer.stop();
        monitor.m_readTimeout.setInterval(100);
        QSignalSpy updates(&monitor, &BatteryMonitor::readingChanged);
        QTRY_COMPARE(updates.count(), 1);
        QVERIFY(!monitor.available());
        QVERIFY(monitor.m_timedOut);
        QTRY_COMPARE(monitor.m_process.state(), QProcess::NotRunning);
        monitor.m_readTimeout.setInterval(3000);
        monitor.m_device = QStringLiteral("sample");
        poll(monitor);
        QVERIFY(monitor.available());
    }

    void failedToStartReader()
    {
        BatteryMonitor monitor(QStringLiteral("/smartslate-no-such-reader"), QString(), nullptr);
        monitor.m_pollTimer.stop();
        QTRY_VERIFY(!monitor.m_lastError.isEmpty());
        QVERIFY(!monitor.available());
        QVERIFY(!monitor.m_readTimeout.isActive());
        QVERIFY(!monitor.m_timedOut);
        QVERIFY(monitor.m_lastError.contains(QStringLiteral("Cannot start battery reader")));
    }
};

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    if (app.arguments().size() == 3 && app.arguments().at(1) == QStringLiteral("--read-battery")) {
        const QString mode = app.arguments().at(2);
        if (mode == QStringLiteral("hang")) {
            QTimer::singleShot(30000, &app, &QCoreApplication::quit);
            return app.exec();
        }
        if (mode == QStringLiteral("failure")) {
            QTextStream(stdout) << "{\"error\":\"Test battery disconnected\"}\n";
            return 1;
        }
        if (mode == QStringLiteral("malformed"))
            QTextStream(stdout) << "broken\n";
        else if (mode == QStringLiteral("missing-fields"))
            QTextStream(stdout) << "{\"percentage\":78}\n";
        else if (mode == QStringLiteral("invalid-voltage"))
            QTextStream(stdout) << "{\"percentage\":78,\"voltage\":0,\"rate\":-20.8}\n";
        else
            QTextStream(stdout) << "{\"percentage\":78,\"voltage\":4,\"rate\":-20.8}\n";
        return 0;
    }
    BatteryTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_battery.moc"
