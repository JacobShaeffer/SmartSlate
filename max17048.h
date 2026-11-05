#pragma once

#include <QString>
#include <QtGlobal>

#include <optional>

namespace Max17048 {

constexpr quint16 Address = 0x36;

struct Sample {
    double percentage;
    double voltage;
    double rate; // Percentage points per hour; negative while discharging.
};

quint16 registerWord(quint8 msb, quint8 lsb);
Sample decode(quint16 soc, quint16 vcell, quint16 crate);
std::optional<Sample> read(const QString &device, QString &error);
int runReader(const QString &device);

} // namespace Max17048
