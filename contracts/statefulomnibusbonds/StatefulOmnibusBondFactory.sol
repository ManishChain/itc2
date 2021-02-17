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
import './StatefulOmnibusBond.sol';
import './StatefulOmnibusBondRegistry.sol';
import './BondManagerFactory.sol';

/**
 * @title Factory contract for stateful omnibus  bond state machines
 */
contract StatefulOmnibusBondFactory is StateMachineFactory {
  event StatefulOmnibusBondCreated(address _address, string _name);

  BondManagerFactory _bondManagerFactory;
  uint8 internal _parValueDecimal;
  uint8 internal _couponRateDecimal;

  constructor(
    GateKeeper gateKeeper,
    StatefulOmnibusBondRegistry registry,
    BondManagerFactory bondManagerFactory
  ) public StateMachineFactory(gateKeeper, registry) {
    _bondManagerFactory = bondManagerFactory;
    _parValueDecimal = 2;
    _couponRateDecimal = 2;
  }

  function getDecimalsFor(bytes memory fieldName) public view returns (uint256) {
    if (
      keccak256(fieldName) == keccak256('_parValue') ||
      keccak256(fieldName) == keccak256('payment') ||
      keccak256(fieldName) == keccak256('price')
    ) {
      return _parValueDecimal;
    }
    if (keccak256(fieldName) == keccak256('_couponRate')) {
      return _couponRateDecimal;
    }
  }

  /**
   * @notice Create new stateful bond
   * @dev Factory method to create a new stateful bond. Emits StateMachineCreated event.
   */
  function create(
    string memory name,
    string memory symbol,
    uint256 parValue,
    uint256 couponRate,
    uint8 decimals,
    bytes32 frequency,
    string memory ipfsFieldContainerHash
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    StatefulOmnibusBond statefulOmnibusBond = new StatefulOmnibusBond(
      name,
      symbol,
      parValue,
      couponRate,
      decimals,
      frequency,
      gateKeeper,
      ipfsFieldContainerHash,
      _uiFieldDefinitionsHash
    );

    // Give every role registry a single permission on the newly created bond.
    bytes32[] memory roles = statefulOmnibusBond.getRoles();
    for (uint256 i = 0; i < roles.length; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(roles[i]),
        address(statefulOmnibusBond),
        roles[i],
        address(this)
      );
    }

    gateKeeper.createPermission(msg.sender, address(statefulOmnibusBond), bytes32('MINT_ROLE'), address(this));
    gateKeeper.createPermission(msg.sender, address(statefulOmnibusBond), bytes32('BURN_ROLE'), address(this));

    _registry.insert(address(statefulOmnibusBond));

    emit StatefulOmnibusBondCreated(address(statefulOmnibusBond), name);

    address bondManagerAddress = _bondManagerFactory.create(name, address(statefulOmnibusBond));

    gateKeeper.grantPermission(bondManagerAddress, address(statefulOmnibusBond), bytes32('MINT_ROLE'));
    gateKeeper.grantPermission(bondManagerAddress, address(statefulOmnibusBond), bytes32('BURN_ROLE'));

    statefulOmnibusBond.setBondManagerAddress(bondManagerAddress);
  }
}
