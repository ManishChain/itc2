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

import '@settlemint/enteth-contracts/contracts/tokens/ERC20/ERC20TokenRegistry.sol';

/**
 * @title Lists all deployed coins
 */
contract LoyaltyPointRegistry is ERC20TokenRegistry {
  constructor(address gateKeeper) public ERC20TokenRegistry(gateKeeper) {}
}
