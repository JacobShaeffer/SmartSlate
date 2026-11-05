#pragma once

#include "batteryestimator.h"

#include <QElapsedTimer>
#include <QObject>
#include <QProcess>
#include <QTimer>

class BatteryMonitor final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY readingChanged)
    Q_PROPERTY(int percentage READ percentage NOTIFY readingChanged)
    Q_PROPERTY(int remainingMinutes READ remainingMinutes NOTIFY readingChanged)
    Q_PROPERTY(bool charging READ charging NOTIFY readingChanged)
    Q_PROPERTY(QString status READ status NOTIFY readingChanged)

public:
    explicit BatteryMonitor(QObject *parent = nullptr);
    ~BatteryMonitor() override;

    bool available() const { return m_available; }
    int percentage() const { return m_percentage; }
    int remainingMinutes() const { return m_estimator.remainingMinutes(); }
    bool charging() const { return m_estimator.charging(); }
    QString status() const { return m_status; }

    Q_INVOKABLE void refresh();

signals:
    void readingChanged();

private:
    friend class BatteryTest;
    BatteryMonitor(const QString &readerPath, const QString &device, QObject *parent);

    void finishReading(int exitCode, QProcess::ExitStatus exitStatus);
    void setUnavailable(const QString &error);

    BatteryEstimator m_estimator;
    QProcess m_process;
    QTimer m_pollTimer;
    QTimer m_readTimeout;
    QElapsedTimer m_lastPoll;
    QString m_device;
    QString m_readerPath;
    QString m_status;
    QString m_lastError;
    int m_percentage = -1;
    bool m_available = false;
    bool m_timedOut = false;
};
