#pragma once

#include <QObject>
#include <QProcess>

class BrightnessController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int brightness READ brightness NOTIFY brightnessChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit BrightnessController(QObject *parent = nullptr);

    int brightness() const { return m_brightness; }
    bool available() const { return m_available; }
    QString status() const { return m_status; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setBrightness(int value);

signals:
    void brightnessChanged();
    void availableChanged();
    void statusChanged();

private:
    enum class Operation { None, Query, Set };

    void setAvailable(bool available);
    void finishQuery(int exitCode, QProcess::ExitStatus exitStatus);
    void finishSet(int exitCode, QProcess::ExitStatus exitStatus);
    void startPendingRequest();
    void setStatus(const QString &status);

    QProcess m_process;
    QString m_ddcutilPath;
    QString m_status;
    int m_brightness = 100;
    int m_pendingBrightness = -1;
    int m_activeBrightness = -1;
    bool m_available = false;
    Operation m_operation = Operation::None;
};
