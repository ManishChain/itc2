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
import './DrugPackage.sol';
import './DrugPackageRegistry.sol';

/**
 * @title Factory contract for drug package state machines
 */
contract DrugPackageFactory is StateMachineFactory {
  constructor(GateKeeper gateKeeper, DrugPackageRegistry registry) public StateMachineFactory(gateKeeper, registry) {}

  /**
   * @notice Create new drug package
   * @dev Factory method to create a new drug package. Emits StateMachineCreated event.
   * @param labellerCode identifying the package labeller
   * @param productCode identifying the product inside the package
   * @param packageCode identifying the package itself
   * @param ipfsFieldContainerHash ipfs hash of drug package metadata
   */
  function create(
    string memory labellerCode,
    string memory productCode,
    string memory packageCode,
    string memory ipfsFieldContainerHash
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    bytes memory memProof = bytes(labellerCode);
    require(memProof.length > 0, 'A labellerCode is required');
    memProof = bytes(productCode);
    require(memProof.length > 0, 'A productCode is required');
    memProof = bytes(packageCode);
    require(memProof.length > 0, 'A packageCode is required');

    DrugPackage drugPackage = new DrugPackage(
      address(gateKeeper),
      labellerCode,
      productCode,
      packageCode,
      ipfsFieldContainerHash,
      _uiFieldDefinitionsHash
    );

    // Give every role registry a single permission on the newly created expense.
    bytes32[] memory roles = drugPackage.getRoles();
    for (uint256 i = 0; i < roles.length; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(roles[i]),
        address(drugPackage),
        roles[i],
        address(this)
      );
    }

    _registry.insert(address(drugPackage));
    emit StateMachineCreated(address(drugPackage));
  }
}
