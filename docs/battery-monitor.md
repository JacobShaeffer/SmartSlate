# MAX17048 battery monitor

Settings displays battery percentage and estimated remaining runtime from the
Adafruit MAX17048 connected to the Raspberry Pi's I2C bus. The app reads the
gauge directly using Linux `i2c-dev`; no Python library or background service is
required. Windows and QML previews display an unavailable state.

## Raspberry Pi setup

Connect the monitor to the Pi's 3.3V, GND, SDA, and SCL connections, and connect
the monitored single-cell LiPo/Li-ion battery to the monitor's battery connector.
The monitor must measure the battery powering the slate, before its 5V converter.
The MAX17048 is a fuel gauge, not a battery charger or a power supply for the Pi.
See [Adafruit's wiring guide](https://learn.adafruit.com/adafruit-max17048-lipoly-liion-fuel-gauge-and-battery-monitor/python-circuitpython).

On Raspberry Pi OS, enable I2C in `sudo raspi-config` under **Interface Options**,
then ensure the account running SmartSlate belongs to the `i2c` group:

```sh
sudo usermod -aG i2c "$USER"
```

Log out and back in after changing group membership. For a systemd service, give
the service account access to the same group, and restart the service.

The default device is `/dev/i2c-1` and the gauge address is `0x36`. To use a
different bus, set the device path in the app's launch environment:

```sh
SMARTSLATE_I2C_DEVICE=/dev/i2c-3 ./appSmartSlate
```

For a systemd service, add `Environment=SMARTSLATE_I2C_DEVICE=/dev/i2c-3` to its
`[Service]` section instead. The app does not scan other buses or force access to
an address owned by a kernel driver.

## Behavior

- The first read starts when the app launches; subsequent reads run every
  10 seconds, even when Settings is closed.
- Percentage comes from the gauge's SOC register, clamped to 0–100% for display.
- Remaining minutes are `ceil(percentage * 60 / abs(dischargeRate))`, using the
  gauge's signed CRATE value in percentage points per hour. The app requires
  three consistent readings (normally about 20 seconds) before showing an
  estimate and smooths rate changes to reduce jumps.
- Near-zero or inconsistent rates show **Estimating…**. Three consistent
  positive-rate readings show **Charging**. Charging is inferred from the
  battery's rate, rather than from a charger or external-power detection pin.
- A failed or timed-out read clears the displayed percentage and estimate.
  Polling continues, and valid readings restore the display automatically.
- Reads run in a headless helper mode of the same executable, with a 3-second
  timeout. The GUI does not wait for I2C operations. No gauge configuration,
  reset, or quick-start commands are written.

Runtime is an estimate at recent usage, not a guaranteed shutdown time. Display
brightness, CPU load, temperature, and the battery protection/5V converter's
cutoff affect actual usable runtime. The feature does not shut down the Pi.

## Diagnostics and validation

Read one sample without starting the graphical interface:

```sh
./appSmartSlate --read-battery /dev/i2c-1
```

Success prints JSON containing `percentage`, `voltage`, and `rate`, and exits
with code 0. Failure prints an `error` and exits with code 1. Normal app runs log
hardware errors to stderr while showing a simple unavailable state in Settings.

The Linux build needs the standard I2C userspace headers (`linux/i2c.h` and
`linux/i2c-dev.h`, provided by `linux-libc-dev` on Raspberry Pi OS).

Build and run the automated checks with the project's Qt toolchain:

```sh
cmake -S . -B build -DBUILD_TESTING=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure
QT_QUICK_BACKEND=software QT_IM_MODULE=qtvirtualkeyboard \
    qmltestrunner -input tests -platform offscreen
```

Native tests cover register decoding, runtime calculations, rate transitions,
reader errors, timeouts, and reconnection. QML tests cover live readings, missing
hardware, charging, themes, and scrolling at the minimum supported window size.
Production builds can use `-DBUILD_TESTING=OFF` to omit the Qt Test dependency.

On the Pi, verify the gauge sample, watch the percentage update in Settings,
disconnect/reconnect the monitor, and confirm charging and discharging behavior.
Compare estimated runtime with a real discharge run and the power converter's
cutoff before relying on it during filming.

Register format references: [MAX17048 datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/MAX17048-MAX17049.pdf)
and [Adafruit's MAX17048 driver](https://github.com/adafruit/Adafruit_MAX1704X).
