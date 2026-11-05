#include "batteryestimator.h"

#include <cmath>

void BatteryEstimator::reset()
{
    m_smoothedRate = 0.0;
    m_lastPercentage = -1.0;
    m_direction = 0;
    m_consistentSamples = 0;
    m_remainingMinutes = -1;
}

void BatteryEstimator::update(const Max17048::Sample &sample)
{
    if (!std::isfinite(sample.percentage) || !std::isfinite(sample.rate)
        || sample.percentage < 0.0 || sample.percentage > 100.0) {
        reset();
        return;
    }

    // Discard history after a battery swap or a large gauge correction.
    if (m_lastPercentage >= 0.0 && std::abs(sample.percentage - m_lastPercentage) > 10.0)
        reset();
    m_lastPercentage = sample.percentage;

    // Ignore rates within two CRATE counts of zero rather than show an
    // enormous runtime or claim charging from noise near idle.
    constexpr double minimumRate = 0.416;
    const int direction = sample.rate < -minimumRate ? -1
                          : sample.rate > minimumRate ? 1 : 0;
    m_remainingMinutes = -1;
    if (direction == 0) {
        m_direction = 0;
        m_consistentSamples = 0;
        m_smoothedRate = 0.0;
        return;
    }

    if (direction != m_direction) {
        m_direction = direction;
        m_consistentSamples = 1;
        m_smoothedRate = sample.rate;
    } else {
        m_consistentSamples = qMin(m_consistentSamples + 1, 3);
        m_smoothedRate += 0.25 * (sample.rate - m_smoothedRate);
    }

    if (m_direction < 0 && m_consistentSamples >= 3) {
        m_remainingMinutes = int(std::ceil(sample.percentage * 60.0 / -m_smoothedRate));
    }
}
