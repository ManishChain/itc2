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
import '@settlemint/enteth-contracts/contracts/tokens/IWithDecimalFields.sol';
import './StatefulBond.sol';
import './StatefulBondRegistry.sol';

/**
 * @title Factory contract for stateful bond state machines
 */
contract StatefulBondFactory is StateMachineFactory, IWithDecimalFields {
  uint8 internal _parValueDecimal;
  uint8 internal _couponRateDecimal;

  constructor(GateKeeper gateKeeper, StatefulBondRegistry registry) public StateMachineFactory(gateKeeper, registry) {
    _parValueDecimal = 2;
    _couponRateDecimal = 2;
  }

  event TokenCreated(address _address, string _name);

  /**
   * @notice Create new stateful bond
   * @dev Factory method to create a new stateful bond. Emits StateMachineCreated event.
   */
  function create(
    string memory name,
    uint256 parValue,
    uint256 couponRate,
    uint8 decimals,
    bytes32 inFlight,
    bytes32 frequency,
    string memory ipfsFieldContainerHash
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    StatefulBond statefulBond = new StatefulBond(
      name,
      parValue,
      couponRate,
      decimals,
      inFlight,
      frequency,
      gateKeeper,
      ipfsFieldContainerHash,
      _uiFieldDefinitionsHash
    );

    // Give every role registry a single permission on the newly created expense.
    bytes32[] memory roles = statefulBond.getRoles();
    for (uint256 i = 0; i < roles.length; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(roles[i]),
        address(statefulBond),
        roles[i],
        address(this)
      );
    }

    gateKeeper.createPermission(msg.sender, address(statefulBond), bytes32('MINT_ROLE'), msg.sender);
    gateKeeper.createPermission(msg.sender, address(statefulBond), bytes32('BURN_ROLE'), msg.sender);

    _registry.insert(address(statefulBond));
    emit StateMachineCreated(address(statefulBond));
    emit TokenCreated(address(statefulBond), name);
  }

  function getDecimalsFor(bytes memory fieldName) public view override returns (uint256) {
    if (keccak256(fieldName) == keccak256('_parValue')) {
      return _parValueDecimal;
    }
    if (keccak256(fieldName) == keccak256('_couponRate')) {
      return _couponRateDecimal;
    }
    return 0;
  }
}
