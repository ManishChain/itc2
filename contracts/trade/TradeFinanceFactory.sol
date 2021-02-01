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

import '@settlemint/enteth-contracts/contracts/provenance/statemachine/StateMachineFactory.sol';
import './TradeFinance.sol';
import './TradeFinanceRegistry.sol';

/**
 * @title Factory contract for tradefinance state machines
 */
contract TradeFinanceFactory is StateMachineFactory {
  constructor(GateKeeper gateKeeper, TradeFinanceRegistry registry)
    public
    StateMachineFactory(gateKeeper, registry)
  {}

  /**
   * @notice Create new tradefinance
   * @dev Factory method to create a new tradefinance. Emits StateMachineCreated event.
   * @param SAP_Number is unique TradeFinance Identification Number
   * @param ipfsFieldContainerHash ipfs hash of tradefinance metadata
   */
  function create(string memory SAP_Number, string memory Bank, string memory Date,  string memory Value, string memory Beneficiary, string memory ipfsFieldContainerHash)
    public
    authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE')
  {
    bytes memory memProof = bytes(SAP_Number);
    require(memProof.length > 0, 'A SAP_Number is required');

    TradeFinance tradefinance = new TradeFinance(
      address(gateKeeper),
      SAP_Number,
      Bank,
      Date,
      Value,
      Beneficiary,
      ipfsFieldContainerHash,
      _uiFieldDefinitionsHash
    );

    // Give every role registry a single permission on the newly created expense.
    bytes32[] memory roles = tradefinance.getRoles();
    for (uint256 i = 0; i < roles.length; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(roles[i]),
        address(tradefinance),
        roles[i],
        address(this)
      );
    }

    _registry.insert(address(tradefinance));
    emit StateMachineCreated(address(tradefinance));
  }
}
