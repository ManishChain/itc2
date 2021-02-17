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

import '@settlemint/enteth-contracts/contracts/authentication/Secured.sol';
import '@settlemint/enteth-contracts/contracts/provenance/statemachine/StateMachine.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/IpfsFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/FileFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/utility/conversions/Converter.sol';

/**
 * Vehicle
 *
 * A verhicle package exists of
 *  - a description of the verhicle where a vehicle is a device that is designed or
 *    used to transport people or cargo over land, water, air, or through space and the
 *    schema for it as defined by https://schema.org/Vehicle
 *  - a VIN number of the individual vehicle modified to fit the Decentralized ID
 *    standard defined here: https://w3c-ccg.github.io/did-spec/
 *
 * @title State machine to track a vehicle
 */
contract Vehicle is Converter, StateMachine, IpfsFieldContainer, FileFieldContainer {
  bytes32 public constant STATE_VIN_REGISTERED = 'STATE_VIN_REGISTERED';
  bytes32 public constant STATE_CAR_MANUFACTURED = 'STATE_CAR_MANUFACTURED';
  bytes32 public constant STATE_CAR_IMPORTED = 'STATE_CAR_IN_COUNTRY';
  bytes32 public constant STATE_LICENSE_PLATE_ASSIGNED = 'STATE_LICENSE_PLATE_ASSIGNED';
  bytes32 public constant STATE_VEHICLE_IN_OPERATION = 'STATE_VEHICLE_IN_OPERATION';
  bytes32 public constant STATE_VEHICLE_IMPOUNDED = 'STATE_VEHICLE_IMPOUNDED';
  bytes32 public constant STATE_VEHICLE_SCRAPPED = 'STATE_VEHICLE_SCRAPPED';
  bytes32 public constant STATE_VEHICLE_EXPORTED = 'STATE_VEHICLE_EXPORTED';

  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_MANUFACTURER = 'ROLE_MANUFACTURER';
  bytes32 public constant ROLE_AGENT = 'ROLE_AGENT';
  bytes32 public constant ROLE_REGULATOR = 'ROLE_REGULATOR';
  bytes32 public constant ROLE_USER = 'ROLE_USER';

  bytes32[] public _roles = [ROLE_ADMIN, ROLE_MANUFACTURER, ROLE_AGENT, ROLE_REGULATOR, ROLE_USER];

  string public _uiFieldDefinitionsHash;
  string private _vin;
  address _owner;
  uint256 private _mileage;

  constructor(
    address gateKeeper,
    string memory vin,
    address owner,
    uint256 mileage,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public Secured(gateKeeper) {
    _vin = vin;
    _owner = owner;
    _mileage = mileage;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    setupStateMachine();
  }

  /**
   * @notice Updates expense properties
   * @param vin the vehicle's updated Vehicle Identification Number
   * @param owner the vehicle's new owner
   * @param mileage the vehicle's updated mileage
   * @param ipfsFieldContainerHash ipfs hash of vehicle metadata
   */
  function edit(
    string memory vin,
    address owner,
    uint256 mileage,
    string memory ipfsFieldContainerHash
  ) public {
    _vin = vin;
    _owner = owner;
    _mileage = mileage;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  /**
   * @notice Returns a DID of the vehicle
   * @dev Returns a unique DID (Decentralized Identifier) for the vehicle.
   * @return string representing the DID of the vehicle
   */
  function DID() public view returns (string memory) {
    return string(abi.encodePacked('did:demo:vehicle:', _vin));
  }

  /**
   * @notice Returns all the roles for this contract
   * @return bytes32[] array of raw bytes representing the roles
   */
  function getRoles() public view returns (bytes32[] memory) {
    return _roles;
  }

  function setupStateMachine() internal override {
    //create all states
    createState(STATE_VIN_REGISTERED);
    createState(STATE_CAR_MANUFACTURED);
    createState(STATE_CAR_IMPORTED);
    createState(STATE_LICENSE_PLATE_ASSIGNED);
    createState(STATE_VEHICLE_IN_OPERATION);
    createState(STATE_VEHICLE_IMPOUNDED);
    createState(STATE_VEHICLE_EXPORTED);
    createState(STATE_VEHICLE_SCRAPPED);

    // add properties
    // STATE_VEHICLE_REGISTERED
    addNextStateForState(STATE_VIN_REGISTERED, STATE_CAR_MANUFACTURED);

    // STATE_VEHICLE_REGISTERED
    addRoleForState(STATE_CAR_MANUFACTURED, ROLE_ADMIN);
    addRoleForState(STATE_CAR_MANUFACTURED, ROLE_MANUFACTURER);
    addNextStateForState(STATE_CAR_MANUFACTURED, STATE_CAR_IMPORTED);
    addNextStateForState(STATE_CAR_MANUFACTURED, STATE_LICENSE_PLATE_ASSIGNED);

    // STATE_VEHICLE_REGISTERED
    addRoleForState(STATE_CAR_IMPORTED, ROLE_ADMIN);
    addRoleForState(STATE_CAR_IMPORTED, ROLE_MANUFACTURER);
    addRoleForState(STATE_CAR_IMPORTED, ROLE_AGENT);
    addRoleForState(STATE_CAR_IMPORTED, ROLE_REGULATOR);
    addNextStateForState(STATE_CAR_IMPORTED, STATE_LICENSE_PLATE_ASSIGNED);

    // STATE_VEHICLE_REGISTERED
    addRoleForState(STATE_LICENSE_PLATE_ASSIGNED, ROLE_ADMIN);
    addRoleForState(STATE_LICENSE_PLATE_ASSIGNED, ROLE_AGENT);
    addRoleForState(STATE_LICENSE_PLATE_ASSIGNED, ROLE_REGULATOR);
    addNextStateForState(STATE_LICENSE_PLATE_ASSIGNED, STATE_VEHICLE_IN_OPERATION);

    // STATE_VEHICLE_IN_OPERATION
    addRoleForState(STATE_VEHICLE_IN_OPERATION, ROLE_ADMIN);
    addRoleForState(STATE_VEHICLE_IN_OPERATION, ROLE_REGULATOR);
    addNextStateForState(STATE_VEHICLE_IN_OPERATION, STATE_VEHICLE_SCRAPPED);
    addNextStateForState(STATE_VEHICLE_IN_OPERATION, STATE_VEHICLE_EXPORTED);
    addNextStateForState(STATE_VEHICLE_IN_OPERATION, STATE_VEHICLE_IMPOUNDED);

    // STATE_VEHICLE_IN_OPERATION
    addRoleForState(STATE_VEHICLE_SCRAPPED, ROLE_ADMIN);
    addRoleForState(STATE_VEHICLE_SCRAPPED, ROLE_AGENT);
    addRoleForState(STATE_VEHICLE_SCRAPPED, ROLE_REGULATOR);

    // STATE_VEHICLE_IN_OPERATION
    addRoleForState(STATE_VEHICLE_EXPORTED, ROLE_ADMIN);
    addRoleForState(STATE_VEHICLE_EXPORTED, ROLE_AGENT);
    addRoleForState(STATE_VEHICLE_EXPORTED, ROLE_REGULATOR);

    addRoleForState(STATE_VEHICLE_IMPOUNDED, ROLE_ADMIN);
    addRoleForState(STATE_VEHICLE_IMPOUNDED, ROLE_REGULATOR);
    addNextStateForState(STATE_LICENSE_PLATE_ASSIGNED, STATE_VEHICLE_IN_OPERATION);

    setInitialState(STATE_VIN_REGISTERED);
  }
}
