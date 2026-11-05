#include "max17048.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTextStream>

#ifdef Q_OS_LINUX
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <linux/i2c-dev.h>
#include <linux/i2c.h>
#include <sys/ioctl.h>
#include <unistd.h>
#endif

quint16 Max17048::registerWord(quint8 msb, quint8 lsb)
{
    return (quint16(msb) << 8) | quint16(lsb);
}

Max17048::Sample Max17048::decode(quint16 soc, quint16 vcell, quint16 crate)
{
    // MAX17048 registers are big endian. CRATE is a signed 16-bit value.
    const int signedRate = crate >= 0x8000 ? int(crate) - 0x10000 : int(crate);
    return {qBound(0.0, soc / 256.0, 100.0),
            vcell * 0.000078125,
            signedRate * 0.208};
}

std::optional<Max17048::Sample> Max17048::read(const QString &device, QString &error)
{
    error.clear();
#ifdef Q_OS_LINUX
    const int fd = ::open(QFile::encodeName(device).constData(), O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        error = QStringLiteral("Cannot open %1: %2")
                    .arg(device, QString::fromLocal8Bit(std::strerror(errno)));
        return std::nullopt;
    }

    // Do not force access if a kernel driver already owns this address.
    if (::ioctl(fd, I2C_SLAVE, Address) < 0) {
        error = QStringLiteral("Cannot select MAX17048 at 0x36 on %1: %2")
                    .arg(device, QString::fromLocal8Bit(std::strerror(errno)));
        ::close(fd);
        return std::nullopt;
    }

    const auto readRegister = [fd, &error](quint8 reg, quint16 &value) {
        quint8 bytes[2] = {};
        i2c_msg messages[2] = {};
        messages[0].addr = Address;
        messages[0].len = 1;
        messages[0].buf = &reg;
        messages[1].addr = Address;
        messages[1].flags = I2C_M_RD;
        messages[1].len = 2;
        messages[1].buf = bytes;
        i2c_rdwr_ioctl_data transfer = {messages, 2};

        // A repeated start keeps register selection and reading atomic.
        const int result = ::ioctl(fd, I2C_RDWR, &transfer);
        if (result != 2) {
            error = QStringLiteral("MAX17048 register 0x%1: %2")
                        .arg(reg, 2, 16, QLatin1Char('0'))
                        .arg(result < 0 ? QString::fromLocal8Bit(std::strerror(errno))
                                        : QStringLiteral("incomplete I2C transfer"));
            return false;
        }
        value = registerWord(bytes[0], bytes[1]);
        return true;
    };

    quint16 version = 0;
    quint16 soc = 0;
    quint16 vcell = 0;
    quint16 crate = 0;
    bool success = readRegister(0x08, version);
    if (success && (version & 0xfff0) != 0x0010) {
        error = QStringLiteral("MAX17048 is not ready; check the battery connection.");
        success = false;
    }
    if (success) {
        success = readRegister(0x04, soc) && readRegister(0x02, vcell)
                  && readRegister(0x16, crate);
    }
    ::close(fd);
    if (!success)
        return std::nullopt;

    const Sample sample = decode(soc, vcell, crate);
    if (sample.voltage <= 0.0 || sample.voltage > 5.0) {
        error = QStringLiteral("MAX17048 returned an invalid cell voltage.");
        return std::nullopt;
    }
    return sample;
#else
    Q_UNUSED(device)
    error = QStringLiteral("MAX17048 monitoring requires Linux I2C.");
    return std::nullopt;
#endif
}

int Max17048::runReader(const QString &device)
{
    QString error;
    const auto sample = read(device, error);
    QJsonObject result;
    if (sample) {
        result = {{QStringLiteral("percentage"), sample->percentage},
                  {QStringLiteral("voltage"), sample->voltage},
                  {QStringLiteral("rate"), sample->rate}};
    } else {
        result.insert(QStringLiteral("error"), error);
    }
    QTextStream(stdout) << QJsonDocument(result).toJson(QJsonDocument::Compact) << '\n';
    return sample ? 0 : 1;
}
