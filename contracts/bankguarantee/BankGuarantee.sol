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
 * BankGuarantee

 *
 * @title State machine for BankGuarantee
 */
contract BankGuarantee is Converter, StateMachine, IpfsFieldContainer, FileFieldContainer {
  bytes32 public constant STATE_INITIATED = 'INITIATED';
  bytes32 public constant STATE_IN_REVIEW = 'IN-REVIEW';
  bytes32 public constant STATE_INCOMPLETE = 'INCOMPLETE';
  bytes32 public constant STATE_APPROVED = 'e-STAMP';
  bytes32 public constant STATE_ISSUED = 'ISSUED';
  bytes32 public constant STATE_ACCEPTED = 'ACCEPTED';
  bytes32 public constant STATE_INVOKED = 'INVOKED';
  bytes32 public constant STATE_AMENDMENT = 'AMENDMENT';
  bytes32 public constant STATE_REJECTED_BANK = 'REJECTED-BANK';
  bytes32 public constant STATE_REJECTED_BENEFICIARY = 'REJECTED-BENEFICIARY';
  bytes32 public constant STATE_FINISHED = 'FINISHED';

  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_BANK = 'ROLE_BANK';
  bytes32 public constant ROLE_BENEFICIARY = 'ROLE_BENEFICIARY';
  bytes32 public constant ROLE_APPLICANT = 'ROLE_APPLICANT';

  bytes32[] public _roles = [ROLE_ADMIN, ROLE_BANK, ROLE_BENEFICIARY, ROLE_APPLICANT];
  bytes32[] private _canEdit = [ROLE_ADMIN, ROLE_BANK, ROLE_APPLICANT];

  string public _uiFieldDefinitionsHash;
  string public _Name;

  constructor(
    address gateKeeper,
    string memory Name,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public Secured(gateKeeper) {
    _Name = Name;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    setupStateMachine();
  }

  function canEdit() public view returns (bytes32[] memory) {
    return _canEdit;
  }

  /**
   * @notice Updates expense properties
   * @param Name It is the order Identification Number
   * @param ipfsFieldContainerHash ipfs hash of bankgurantee metadata
   */
  function edit(string memory Name, string memory ipfsFieldContainerHash) public {
    _Name = Name;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  /**
   * @notice Returns a DID of the bankgurantee
   * @dev Returns a unique DID (Decentralized Identifier) for the bankgurantee.
   * @return string representing the DID of the bankgurantee
   */
  function DID() public view returns (string memory) {
    return string(abi.encodePacked('did:demo:bankgurantee:', _Name));
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
    createState(STATE_INITIATED);
    createState(STATE_IN_REVIEW);
    createState(STATE_INCOMPLETE);
    createState(STATE_APPROVED);
    createState(STATE_ISSUED);
    createState(STATE_ACCEPTED);
    createState(STATE_INVOKED);
    createState(STATE_AMENDMENT);
    createState(STATE_REJECTED_BANK);
    createState(STATE_REJECTED_BENEFICIARY);
    createState(STATE_FINISHED);

    setInitialState(STATE_INITIATED);

    addRoleForState(STATE_INITIATED, ROLE_BANK);
    addRoleForState(STATE_INITIATED, ROLE_APPLICANT);

    addRoleForState(STATE_IN_REVIEW, ROLE_APPLICANT);

    addAllowedFunctionForState(STATE_INITIATED, this.edit.selector);
    addAllowedFunctionForState(STATE_APPROVED, this.edit.selector);

    addRoleForState(STATE_ISSUED, ROLE_BANK);
    addRoleForState(STATE_INCOMPLETE, ROLE_BANK);
    addRoleForState(STATE_APPROVED, ROLE_BANK);
    addRoleForState(STATE_REJECTED_BANK, ROLE_BANK);
    addRoleForState(STATE_FINISHED, ROLE_BANK);

    addRoleForState(STATE_REJECTED_BENEFICIARY, ROLE_BENEFICIARY);
    addRoleForState(STATE_ACCEPTED, ROLE_BENEFICIARY);
    addRoleForState(STATE_INVOKED, ROLE_BENEFICIARY);
    addRoleForState(STATE_AMENDMENT, ROLE_BENEFICIARY);

    //addRoleForState(STATE_INITIATED,ROLE_ADMIN);
    //addRoleForState(STATE_READY,ROLE_ADMIN);
    //addRoleForState(STATE_IN_REVIEW,ROLE_ADMIN);
    //addRoleForState(STATE_INCOMPLETE,ROLE_ADMIN);
    //addRoleForState(STATE_APPROVED,ROLE_ADMIN);
    //addRoleForState(STATE_ISSUED,ROLE_ADMIN);
    //addRoleForState(STATE_ACCEPTED,ROLE_ADMIN);
    //addRoleForState(STATE_INVOKED,ROLE_ADMIN);
    //addRoleForState(STATE_AMENDMENT,ROLE_ADMIN);
    //addRoleForState(STATE_REJECTED_BANK,ROLE_ADMIN);
    //addRoleForState(STATE_FINISHED,ROLE_ADMIN);

    // add properties

    addNextStateForState(STATE_INITIATED, STATE_IN_REVIEW);

    addNextStateForState(STATE_IN_REVIEW, STATE_INCOMPLETE);
    addNextStateForState(STATE_IN_REVIEW, STATE_APPROVED);
    addNextStateForState(STATE_IN_REVIEW, STATE_REJECTED_BANK);

    addNextStateForState(STATE_INCOMPLETE, STATE_IN_REVIEW);
    addNextStateForState(STATE_APPROVED, STATE_ISSUED);
    addNextStateForState(STATE_REJECTED_BANK, STATE_FINISHED);

    addNextStateForState(STATE_ISSUED, STATE_REJECTED_BENEFICIARY);
    addNextStateForState(STATE_ISSUED, STATE_ACCEPTED);

    addNextStateForState(STATE_ACCEPTED, STATE_INVOKED);
    addNextStateForState(STATE_ACCEPTED, STATE_AMENDMENT);

    addNextStateForState(STATE_AMENDMENT, STATE_ISSUED);
    addNextStateForState(STATE_AMENDMENT, STATE_REJECTED_BANK);

    addNextStateForState(STATE_INVOKED, STATE_FINISHED);

    addNextStateForState(STATE_REJECTED_BENEFICIARY, STATE_FINISHED);
  }
}
