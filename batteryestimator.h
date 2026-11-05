#pragma once

#include "max17048.h"

class BatteryEstimator
{
public:
    void update(const Max17048::Sample &sample);
    void reset();

    int remainingMinutes() const { return m_remainingMinutes; }
    bool charging() const { return m_direction > 0 && m_consistentSamples >= 3; }

private:
    double m_smoothedRate = 0.0;
    double m_lastPercentage = -1.0;
    int m_direction = 0;
    int m_consistentSamples = 0;
    int m_remainingMinutes = -1;
};
