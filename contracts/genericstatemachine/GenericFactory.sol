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
import './Generic.sol';
import './GenericRegistry.sol';

/**
 * @title Factory contract for generic state machines
 */
contract GenericFactory is StateMachineFactory {
  constructor(GateKeeper gateKeeper, GenericRegistry registry) public StateMachineFactory(gateKeeper, registry) {}

  /**
   * @notice Create new generic instance
   * @dev Factory method to create a new state machine. Emits StateMachineCreated event.
   * @param param1 the first parameter of the state machine
   * @param param2 the second parameter of the state machine
   * @param param3 the third parameter of the state machine
   * @param ipfsFieldContainerHash ipfs hash of vehicle metadata
   */
  function create(
    string memory param1,
    address param2,
    uint256 param3,
    string memory ipfsFieldContainerHash
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    bytes memory memProof = bytes(param1);
    require(memProof.length > 0, 'A param1 is required');

    Generic generic = new Generic(
      address(gateKeeper),
      param1,
      param2,
      param3,
      ipfsFieldContainerHash,
      _uiFieldDefinitionsHash
    );

    // Give every role registry a single permission on the newly created expense.
    bytes32[] memory roles = generic.getRoles();
    for (uint256 i = 0; i < 1; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(roles[i]),
        address(generic),
        roles[i],
        address(this)
      );
    }
    _registry.insert(address(generic));
    emit StateMachineCreated(address(generic));
  }
}
