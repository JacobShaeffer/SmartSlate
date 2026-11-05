#include "batterymonitor.h"

#include <QCoreApplication>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>

#include <cmath>

BatteryMonitor::BatteryMonitor(QObject *parent)
    : BatteryMonitor(
#ifdef Q_OS_LINUX
          QCoreApplication::applicationFilePath(),
#else
          QString(),
#endif
          qEnvironmentVariable("SMARTSLATE_I2C_DEVICE", QStringLiteral("/dev/i2c-1")), parent)
{
}

BatteryMonitor::BatteryMonitor(const QString &readerPath, const QString &device, QObject *parent)
    : QObject(parent)
    , m_device(device)
    , m_readerPath(readerPath)
{
    m_pollTimer.setInterval(10000);
    m_pollTimer.setTimerType(Qt::PreciseTimer);
    m_readTimeout.setInterval(3000);
    m_readTimeout.setSingleShot(true);
    connect(&m_pollTimer, &QTimer::timeout, this, &BatteryMonitor::refresh);
    connect(&m_process, &QProcess::finished, this, &BatteryMonitor::finishReading);
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            m_readTimeout.stop();
            setUnavailable(QStringLiteral("Cannot start battery reader: %1")
                               .arg(m_process.errorString()));
        }
    });
    connect(&m_readTimeout, &QTimer::timeout, this, [this]() {
        m_timedOut = true;
        m_process.kill();
        setUnavailable(QStringLiteral("MAX17048 read timed out on %1").arg(m_device));
    });

    if (m_readerPath.isEmpty()) {
        m_status = tr("Battery monitoring is available on the Raspberry Pi.");
    } else {
        m_status = tr("Checking battery…");
        m_pollTimer.start();
        refresh();
    }
}

BatteryMonitor::~BatteryMonitor()
{
    m_pollTimer.stop();
    m_readTimeout.stop();
    m_process.disconnect(this);
    if (m_process.state() != QProcess::NotRunning) {
        m_process.kill();
        m_process.waitForFinished(1000);
    }
}

void BatteryMonitor::refresh()
{
    if (m_readerPath.isEmpty() || m_process.state() != QProcess::NotRunning)
        return;
    // Opening Settings repeatedly must not count as several stable samples.
    if (m_lastPoll.isValid() && m_lastPoll.elapsed() < m_pollTimer.interval())
        return;
    if (m_lastPoll.isValid() && m_lastPoll.elapsed() > 30000)
        setUnavailable(QStringLiteral("Battery readings expired."));

    m_lastPoll.start();
    m_timedOut = false;
    // The same executable reads I2C in a headless helper mode. A stuck kernel
    // transaction can then be killed without blocking the GUI thread.
    m_readTimeout.start();
    m_process.start(m_readerPath, {QStringLiteral("--read-battery"), m_device});
}

void BatteryMonitor::finishReading(int exitCode, QProcess::ExitStatus exitStatus)
{
    m_readTimeout.stop();
    const QByteArray output = m_process.readAllStandardOutput();
    m_process.readAllStandardError();
    if (m_timedOut)
        return;

    const QJsonDocument document = QJsonDocument::fromJson(output);
    const QJsonObject result = document.object();
    if (exitStatus != QProcess::NormalExit || exitCode != 0 || !document.isObject()) {
        setUnavailable(result.value(QStringLiteral("error")).toString(
            QStringLiteral("Could not read the MAX17048 on %1.").arg(m_device)));
        return;
    }

    const auto percentage = result.value(QStringLiteral("percentage"));
    const auto voltage = result.value(QStringLiteral("voltage"));
    const auto rate = result.value(QStringLiteral("rate"));
    if (!percentage.isDouble() || !voltage.isDouble() || !rate.isDouble()
        || !std::isfinite(percentage.toDouble()) || !std::isfinite(voltage.toDouble())
        || !std::isfinite(rate.toDouble()) || percentage.toDouble() < 0.0
        || percentage.toDouble() > 100.0 || voltage.toDouble() <= 0.0
        || voltage.toDouble() > 5.0) {
        setUnavailable(QStringLiteral("MAX17048 returned an invalid reading."));
        return;
    }

    m_estimator.update({percentage.toDouble(), voltage.toDouble(), rate.toDouble()});
    m_percentage = qRound(percentage.toDouble());
    m_available = true;
    m_lastError.clear();
    m_status = charging() ? tr("Runtime estimate resumes when discharging.")
               : remainingMinutes() >= 0 ? tr("Based on recent usage.")
                                         : tr("Waiting for a steady discharge rate.");
    emit readingChanged();
}

void BatteryMonitor::setUnavailable(const QString &error)
{
    m_estimator.reset();
    m_percentage = -1;
    m_available = false;
    m_status = tr("Battery monitor unavailable.");
    if (error != m_lastError) {
        qWarning().noquote() << "Battery:" << error;
        m_lastError = error;
    }
    emit readingChanged();
}
