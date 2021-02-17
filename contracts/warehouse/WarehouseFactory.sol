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
import './Warehouse.sol';
import './WarehouseRegistry.sol';

/**
 * @title Factory contract for warehouse state machines
 */
contract WarehouseFactory is StateMachineFactory {
  constructor(GateKeeper gateKeeper, WarehouseRegistry registry) public StateMachineFactory(gateKeeper, registry) {}

  /**
   * @notice Create new Warehouse
   * @dev Factory method to create a new Warehouse. Emits StateMachineCreated event.
   * @param Invoice Customer Invoice

   * @param ipfsFieldContainerHash ipfs hash of Warehouse metadata
   */
  function create(string memory Invoice, string memory ipfsFieldContainerHash)
    public
    authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE')
  {
    bytes memory memProof = bytes(Invoice);
    require(memProof.length > 0, 'Invoice is required');

    Warehouse warehouse = new Warehouse(
      address(gateKeeper),
      Invoice,
      ipfsFieldContainerHash,
      _uiFieldDefinitionsHash
    );

    // Give every role registry a single permission on the newly created expense.
    bytes32[] memory roles = warehouse.getRoles();
    for (uint256 i = 0; i < roles.length; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(roles[i]),
        address(warehouse),
        roles[i],
        address(this)
      );
    }

    _registry.insert(address(warehouse));
    emit StateMachineCreated(address(warehouse));
  }
}
