#include "brightnesscontroller.h"

#include <QRegularExpression>
#include <QStandardPaths>

BrightnessController::BrightnessController(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_LINUX
    m_ddcutilPath = QStandardPaths::findExecutable(QStringLiteral("ddcutil"));
    m_status = m_ddcutilPath.isEmpty()
        ? tr("Brightness disabled: ddcutil is not installed.")
        : tr("Checking the DDC/CI display…");
#else
    m_status = tr("Brightness disabled: this control requires Linux and ddcutil.");
#endif

    connect(&m_process, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
        const Operation completedOperation = m_operation;
        m_operation = Operation::None;
        if (completedOperation == Operation::Query)
            finishQuery(exitCode, exitStatus);
        else if (completedOperation == Operation::Set)
            finishSet(exitCode, exitStatus);
    });

    connect(&m_process, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            m_activeBrightness = -1;
            m_pendingBrightness = -1;
            m_operation = Operation::None;
            setAvailable(false);
            setStatus(tr("Brightness failed: could not start ddcutil."));
        }
    });

#ifdef Q_OS_LINUX
    if (!m_ddcutilPath.isEmpty())
        refresh();
#endif
}

void BrightnessController::refresh()
{
    if (m_ddcutilPath.isEmpty())
        return;
    if (m_process.state() != QProcess::NotRunning)
        return;

    m_pendingBrightness = -1;
    setAvailable(false);
    setStatus(tr("Checking the DDC/CI display…"));
    m_operation = Operation::Query;
    m_process.start(m_ddcutilPath,
                    {QStringLiteral("getvcp"), QStringLiteral("10"),
                     QStringLiteral("--brief")});
}

void BrightnessController::setBrightness(int value)
{
    if (!m_available) {
        setStatus(tr("Brightness disabled: ddcutil is not available."));
        return;
    }

    m_pendingBrightness = qBound(0, value, 100);
    startPendingRequest();
}

void BrightnessController::startPendingRequest()
{
    if (!m_available || m_pendingBrightness < 0
        || m_process.state() != QProcess::NotRunning) {
        return;
    }

    m_activeBrightness = m_pendingBrightness;
    m_pendingBrightness = -1;
    setStatus(tr("Setting display brightness…"));
    m_operation = Operation::Set;
    m_process.start(m_ddcutilPath,
                    {QStringLiteral("setvcp"), QStringLiteral("10"),
                     QString::number(m_activeBrightness)});
}

void BrightnessController::setAvailable(bool available)
{
    if (m_available == available)
        return;

    m_available = available;
    emit availableChanged();
}

void BrightnessController::finishQuery(int exitCode, QProcess::ExitStatus exitStatus)
{
    const QString output = QString::fromLocal8Bit(m_process.readAllStandardOutput()).trimmed();
    QString error = QString::fromLocal8Bit(m_process.readAllStandardError()).trimmed();

    int current = -1;
    int maximum = -1;
    if (exitStatus == QProcess::NormalExit && exitCode == 0) {
        QRegularExpressionMatch match = QRegularExpression(
            QStringLiteral(R"(current value\s*=\s*(\d+).*max value\s*=\s*(\d+))"),
            QRegularExpression::CaseInsensitiveOption).match(output);
        if (!match.hasMatch()) {
            match = QRegularExpression(
                QStringLiteral(R"(\bC\s+(\d+)\s+(\d+)\s*$)"),
                QRegularExpression::CaseInsensitiveOption).match(output);
        }
        if (match.hasMatch()) {
            current = match.captured(1).toInt();
            maximum = match.captured(2).toInt();
        }
    }

    if (current >= 0 && maximum > 0) {
        const int percent = qBound(0, qRound(current * 100.0 / maximum), 100);
        if (m_brightness != percent) {
            m_brightness = percent;
            emit brightnessChanged();
        }
        setAvailable(true);
        setStatus(tr("Display brightness is %1%.").arg(percent));
        return;
    }

    setAvailable(false);
    if (error.isEmpty())
        error = output;
    if (error.isEmpty())
        error = tr("No DDC/CI brightness response was received.");
    setStatus(tr("Brightness disabled: %1").arg(error));
}

void BrightnessController::finishSet(int exitCode, QProcess::ExitStatus exitStatus)
{
    const int completedBrightness = m_activeBrightness;
    m_activeBrightness = -1;

    if (exitStatus == QProcess::NormalExit && exitCode == 0) {
        if (m_brightness != completedBrightness) {
            m_brightness = completedBrightness;
            emit brightnessChanged();
        }
        setStatus(tr("Display brightness set to %1%.").arg(completedBrightness));
        startPendingRequest();
        return;
    }

    QString error = QString::fromLocal8Bit(m_process.readAllStandardError()).trimmed();
    if (error.isEmpty())
        error = QString::fromLocal8Bit(m_process.readAllStandardOutput()).trimmed();
    if (error.isEmpty())
        error = tr("ddcutil could not update the display.");
    m_pendingBrightness = -1;
    setAvailable(false);
    setStatus(tr("Brightness disabled: %1").arg(error));
}

void BrightnessController::setStatus(const QString &status)
{
    if (m_status == status)
        return;

    m_status = status;
    emit statusChanged();
}
