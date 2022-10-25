// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ICurveV1Adapter } from "./ICurveV1Adapter.sol";
import { ICurvePool2Assets } from "../../../integrations/curve/ICurvePool_2.sol";

interface ICurveV1_2AssetsAdapter is ICurveV1Adapter, ICurvePool2Assets {}
