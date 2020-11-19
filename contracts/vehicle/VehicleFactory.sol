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
import './Vehicle.sol';
import './VehicleRegistry.sol';

/**
 * @title Factory contract for vehicle state machines
 */
contract VehicleFactory is StateMachineFactory {
  constructor(GateKeeper gateKeeper, VehicleRegistry registry) public StateMachineFactory(gateKeeper, registry) {}

  /**
   * @notice Create new vehicle
   * @dev Factory method to create a new vehicle. Emits StateMachineCreated event.
   * @param vin the vehicle's unique Vehicle Identification Number
   * @param owner the vehicle's current owner
   * @param mileage the vehicle's mileage
   * @param ipfsFieldContainerHash ipfs hash of vehicle metadata
   */
  function create(
    string memory vin,
    address owner,
    uint256 mileage,
    string memory ipfsFieldContainerHash
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    bytes memory memProof = bytes(vin);
    require(memProof.length > 0, 'A vin is required');

    Vehicle vehicle = new Vehicle(
      address(gateKeeper),
      vin,
      owner,
      mileage,
      ipfsFieldContainerHash,
      _uiFieldDefinitionsHash
    );

    // Give every role registry a single permission on the newly created expense.
    bytes32[] memory roles = vehicle.getRoles();
    for (uint256 i = 0; i < roles.length; i++) {
      gateKeeper.createPermission(
        gateKeeper.getRoleRegistryAddress(roles[i]),
        address(vehicle),
        roles[i],
        address(this)
      );
    }

    _registry.insert(address(vehicle));
    emit StateMachineCreated(address(vehicle));
  }
}
