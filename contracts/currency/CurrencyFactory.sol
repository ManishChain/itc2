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

import '@settlemint/enteth-contracts/contracts/tokens/ERC20/ERC20TokenFactory.sol';
import './Currency.sol';

/**
 * @title Factory contract for ERC20-based currency token
 */
contract CurrencyFactory is ERC20TokenFactory {
  constructor(address registry, address gk) public ERC20TokenFactory(registry, gk) {}

  /**
   * @notice Factory method to create new ERC20-based currency token.
   * @dev Restricted to user with the "CREATE_TOKEN_ROLE" permission.
   * @param name bytes32
   * @param decimals bytes32
   */
  function createToken(string memory name, uint8 decimals)
    public
    authWithCustomReason(CREATE_TOKEN_ROLE, 'Sender needs CREATE_TOKEN_ROLE')
  {
    Currency newToken = new Currency(name, decimals, address(gateKeeper), _uiFieldDefinitionsHash);
    _tokenRegistry.addToken(name, address(newToken));
    emit TokenCreated(address(newToken), name);
    gateKeeper.createPermission(msg.sender, address(newToken), bytes32('MINT_ROLE'), msg.sender);
    gateKeeper.createPermission(msg.sender, address(newToken), bytes32('BURN_ROLE'), msg.sender);
    gateKeeper.createPermission(msg.sender, address(newToken), bytes32('UPDATE_METADATA_ROLE'), msg.sender);
    gateKeeper.createPermission(msg.sender, address(newToken), bytes32('EDIT_ROLE'), msg.sender);
  }
}
