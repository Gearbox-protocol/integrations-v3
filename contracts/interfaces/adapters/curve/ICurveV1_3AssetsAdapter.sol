// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { IAdapter } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import { ICurveV1Adapter } from "./ICurveV1Adapter.sol";
import { ICurvePool3Assets } from "../../../integrations/curve/ICurvePool_3.sol";

interface ICurveV1_3AssetsAdapter is ICurveV1Adapter, ICurvePool3Assets {}
