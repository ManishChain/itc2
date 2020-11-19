/**
 * Copyright (C) SettleMint NV - All Rights Reserved
 *
 * Use of this file is strictly prohibited without an active license agreement.
 * Distribution of this file, via any medium, is strictly prohibited.
 *
 * For license inquiries, contact hello@settlemint.com
 *
 * SPDX-License-Identifier: UNLICENSED
 */

pragma solidity ^0.6.3;

pragma experimental ABIEncoderV2;

import '@settlemint/enteth-contracts/contracts/utility/upgrading/UpgradeableRegistry.sol';

/**
 * @title Registry contract for identity digital twins
 */
contract IdentityRegistry is UpgradeableRegistry {
  constructor(address gatekeeper) public UpgradeableRegistry(gatekeeper) {}
}
