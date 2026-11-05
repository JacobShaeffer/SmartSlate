#include <QCursor>
#include <QDebug>
#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include "batterymonitor.h"
#include "brightnesscontroller.h"
#include "max17048.h"

int main(int argc, char *argv[])
{
    if (argc > 1 && qstrcmp(argv[1], "--read-battery") == 0) {
        QCoreApplication app(argc, argv);
        if (app.arguments().size() != 3) {
            qCritical("Usage: appSmartSlate --read-battery /dev/i2c-1");
            return 2;
        }
        return Max17048::runReader(app.arguments().at(2));
    }

    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
    qputenv("QT_VIRTUALKEYBOARD_DESKTOP_DISABLE", QByteArray("1"));

    QGuiApplication app(argc, argv);
    QGuiApplication::setOverrideCursor(QCursor(Qt::BlankCursor));

    BrightnessController brightnessController;
    BatteryMonitor batteryMonitor;
    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("SmartSlate", "Main");
    if (!engine.rootObjects().isEmpty()) {
        engine.rootObjects().constFirst()->setProperty(
            "brightnessController",
            QVariant::fromValue(static_cast<QObject *>(&brightnessController)));
        engine.rootObjects().constFirst()->setProperty(
            "batteryMonitor",
            QVariant::fromValue(static_cast<QObject *>(&batteryMonitor)));
    }

    return QGuiApplication::exec();
}
