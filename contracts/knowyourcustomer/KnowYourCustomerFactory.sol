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
import './KnowYourCustomer.sol';
import './KnowYourCustomerRegistry.sol';

/**
 * @title Factory contract for knowyourcustomer state machines
 */
contract KnowYourCustomerFactory is StateMachineFactory {
  constructor(GateKeeper gateKeeper, KnowYourCustomerRegistry registry)
    public
    StateMachineFactory(gateKeeper, registry)
  {}

  /**
   * @notice Create new knowyourcustomer
   * @dev Factory method to create a new knowyourcustomer. Emits StateMachineCreated event.
   * @param Name Customer Name

   * @param ipfsFieldContainerHash ipfs hash of knowyourcustomer metadata
   */
  function create(string memory Name, string memory ipfsFieldContainerHash)
    public
    authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE')
  {
    bytes memory memProof = bytes(Name);
    require(memProof.length > 0, 'A Name is required');

    KnowYourCustomer knowyourcustomer = new KnowYourCustomer(
      address(gateKeeper),
      Name,
      ipfsFieldContainerHash,
      _uiFieldDefinitionsHash
    );

    // Give every role registry a single permission on the newly created expense.
    bytes32[] memory roles = knowyourcustomer.getRoles();
    for (uint256 i = 0; i < roles.length; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(roles[i]),
        address(knowyourcustomer),
        roles[i],
        address(this)
      );
    }

    _registry.insert(address(knowyourcustomer));
    emit StateMachineCreated(address(knowyourcustomer));
  }
}
