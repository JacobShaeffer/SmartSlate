#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include "brightnesscontroller.h"

int main(int argc, char *argv[])
{
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
    qputenv("QT_VIRTUALKEYBOARD_DESKTOP_DISABLE", QByteArray("1"));

    QGuiApplication app(argc, argv);

    BrightnessController brightnessController;
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
    }

    return QGuiApplication::exec();
}
