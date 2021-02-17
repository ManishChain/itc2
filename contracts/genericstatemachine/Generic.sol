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
 * Generic
 *
 * A generic package exists of
 *  - a description of the generic state machine
 *
 * @title Generic State machine implementation
 */
contract Generic is Converter, StateMachine, IpfsFieldContainer, FileFieldContainer {
  bytes32 public constant STATE_ONE = 'CHANGE_HERE_STATE_ONE';
  bytes32 public constant STATE_TWO = 'CHANGE_HERE_STATE_TWO';
  bytes32 public constant STATE_THREE = 'CHANGE_HERE_STATE_THREE';
  bytes32 public constant STATE_FOUR = 'CHANGE_HERE_STATE_FOUR';
  bytes32 public constant STATE_FIVE = 'CHANGE_HERE_STATE_FIVE';

  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_ONE = 'CHANGE_HERE_ROLE_ONE';
  bytes32 public constant ROLE_TWO = 'CHANGE_HERE_ROLE_TWO';
  bytes32 public constant ROLE_THREE = 'CHANGE_HERE_ROLE_THREE';
  bytes32 public constant ROLE_FOUR = 'CHANGE_HERE_ROLE_FOUR';

  bytes32[] public _roles = [ROLE_ADMIN];

  string public _uiFieldDefinitionsHash;
  string private _param1;
  address _param2;
  uint256 private _param3;

  constructor(
    address gateKeeper,
    string memory param1,
    address param2,
    uint256 param3,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public Secured(gateKeeper) {
    _param1 = param1;
    _param2 = param2;
    _param3 = param3;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    setupStateMachine();
  }

  /**
   * @notice Updates state machine properties
   * @param param1 the first parameter of the state machine
   * @param param2 the second parameter of the state machine
   * @param param3 the third parameter of the state machine
   * @param ipfsFieldContainerHash ipfs hash of vehicle metadata
   */
  function edit(
    string memory param1,
    address param2,
    uint256 param3,
    string memory ipfsFieldContainerHash
  ) public {
    _param1 = param1;
    _param2 = param2;
    _param3 = param3;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
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
    createState(STATE_ONE);
    createState(STATE_TWO);
    createState(STATE_THREE);
    createState(STATE_FOUR);
    createState(STATE_FIVE);

    // add properties
    // STATE_ONE
    addNextStateForState(STATE_ONE, STATE_TWO);
    addRoleForState(STATE_ONE, ROLE_ADMIN);

    // STATE_TWO
    addNextStateForState(STATE_TWO, STATE_THREE);
    addRoleForState(STATE_TWO, ROLE_ADMIN);
    addRoleForState(STATE_TWO, ROLE_ONE);

    // STATE_THREE
    addNextStateForState(STATE_THREE, STATE_FOUR);
    addRoleForState(STATE_THREE, ROLE_ADMIN);
    addRoleForState(STATE_THREE, ROLE_TWO);

    // STATE_FOUR
    addNextStateForState(STATE_FOUR, STATE_FIVE);
    addRoleForState(STATE_FOUR, ROLE_ADMIN);
    addRoleForState(STATE_FOUR, ROLE_THREE);

    // STATE_FIVE
    addRoleForState(STATE_FIVE, ROLE_FOUR);

    setInitialState(STATE_ONE);
  }
}
