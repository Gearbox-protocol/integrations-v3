// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ICurveV1Adapter } from "./ICurveV1Adapter.sol";
import { ICurvePool4Assets } from "../../../integrations/curve/ICurvePool_4.sol";

interface ICurveV1_4AssetsAdapter is ICurveV1Adapter, ICurvePool4Assets {}
