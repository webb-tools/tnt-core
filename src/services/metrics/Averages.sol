// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IMetricComputation } from "core/services/metrics/IMetricComputation.sol";
import { exp, div, mul } from "math/ud60x18/Math.sol";
import { add } from "math/ud60x18/Helpers.sol";
import { LOG2_E } from "math/ud60x18/Constants.sol";
import { UD60x18 } from "math/ud60x18/ValueType.sol";

contract SimpleMovingAverage is IMetricComputation {
    uint256 public immutable period;

    constructor(uint256 _period) {
        require(_period > 0, "Period must be greater than 0");
        period = _period;
    }

    function compute(uint256[] memory values, uint256[] memory) external view override returns (uint256) {
        require(values.length > 0, "No data");
        uint256 sum = 0;
        uint256 count = min(values.length, period);
        for (uint256 i = values.length - count; i < values.length; i++) {
            sum += values[i];
        }
        return count > 0 ? sum / count : 0;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract WeightedMovingAverage is IMetricComputation {
    uint256[] public weights;
    uint256 public immutable totalWeight;

    constructor(uint256[] memory _weights) {
        require(_weights.length > 0, "Weights array must not be empty");
        weights = _weights;
        uint256 _totalWeight = 0;
        for (uint256 i = 0; i < _weights.length; i++) {
            _totalWeight += _weights[i];
        }
        totalWeight = _totalWeight;
    }

    function compute(uint256[] memory values, uint256[] memory) external view override returns (uint256) {
        require(values.length > 0, "No data");
        uint256 weightedSum = 0;
        uint256 usedWeights = 0;
        for (uint256 i = 0; i < min(values.length, weights.length); i++) {
            uint256 value = values[values.length - i - 1];
            uint256 weight = weights[weights.length - i - 1];
            weightedSum += value * weight;
            usedWeights += weight;
        }
        return usedWeights > 0 ? weightedSum / usedWeights : 0;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract ExponentialMovingAverage is IMetricComputation {
    uint256 public immutable alpha;
    uint256 public constant SCALE = 1e18;

    constructor(uint256 _alpha) {
        require(_alpha > 0 && _alpha <= SCALE, "Alpha must be between 0 and 1e18");
        alpha = _alpha;
    }

    function compute(uint256[] memory values, uint256[] memory) external view override returns (uint256) {
        require(values.length > 0, "No data");

        UD60x18 ema = UD60x18.wrap(values[0]);
        UD60x18 alphaUD = UD60x18.wrap(alpha);
        UD60x18 oneMinusAlpha = UD60x18.wrap(SCALE - alpha);

        for (uint256 i = 1; i < values.length; i++) {
            // EMA = alpha * value + (1 - alpha) * EMA
            ema = add(mul(alphaUD, UD60x18.wrap(values[i])), mul(oneMinusAlpha, ema));
        }

        return ema.unwrap();
    }
}
