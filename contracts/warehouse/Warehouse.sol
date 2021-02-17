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
 * Warehouse

 *
 * @title State machine for Warehouse
 */
contract Warehouse is Converter, StateMachine, IpfsFieldContainer, FileFieldContainer {

  bytes32 public constant STATE_INITIATED = 'INITIATED';
  bytes32 public constant STATE_ARRIVED = 'ARRIVED';
  bytes32 public constant STATE_VERIFIED = 'VERIFIED';
  bytes32 public constant STATE_INSPECTED = 'INSPECTED';
  bytes32 public constant STATE_FAILED = 'FAILED';
  bytes32 public constant STATE_RETURNED = 'RETURNED';
  bytes32 public constant STATE_OUT = 'OUT';
  bytes32 public constant STATE_WEIGH = 'WEIGH';
  bytes32 public constant STATE_WEIGH_SLIP = 'WEIGH_SLIP';
  bytes32 public constant STATE_MOVE_GODOWN = 'MOVE_GODOWN';
  bytes32 public constant STATE_UPLOAD_SLIP = 'UPLOAD_SLIP';
  bytes32 public constant STATE_SAMPLE_COLLECT = 'SAMPLE_COLLECT';
  bytes32 public constant STATE_QUALITY_CHECK = 'QUALITY_CHECK';
  bytes32 public constant STATE_TARE_WEIGH = 'TARE_WEIGH';
  bytes32 public constant STATE_GRN_ENTRY = 'GRN_ENTRY';
  bytes32 public constant STATE_GRM_BRANCH = 'GRM_BRANCH';
  bytes32 public constant STATE_GRN_VERIFIED = 'GRN_VERIFIED';
  bytes32 public constant STATE_GRN_FINANCE = 'GRN_FINANCE';
  bytes32 public constant STATE_SAUDA_VERIFY = 'SAUDA_VERIFY';
  bytes32 public constant STATE_SAUDA_FAILED = 'SAUDA_FAILED';
  bytes32 public constant STATE_GRN_REVERSAL = 'GRN_REVERSAL';
  bytes32 public constant STATE_GRN_NEW = 'GRN_NEW';
  bytes32 public constant STATE_SAP_ENTRY = 'SAP_ENTRY';
  bytes32 public constant STATE_CASH_DISCOUNT = 'CASH_DISCOUNT';
  bytes32 public constant STATE_PAYMENT = 'PAYMENT';
  bytes32 public constant STATE_COMPLETE = 'COMPLETE';

  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_TM = 'ROLE_TM';
  bytes32 public constant ROLE_SEC = 'ROLE_SEC';
  bytes32 public constant ROLE_REP = 'ROLE_REP';
  bytes32 public constant ROLE_WSP = 'ROLE_WSP';
  bytes32 public constant ROLE_BOM = 'ROLE_BOM';
  bytes32 public constant ROLE_FM = 'ROLE_FM';

  bytes32[] public _roles = [ROLE_ADMIN, ROLE_TM, ROLE_SEC, ROLE_REP, ROLE_WSP, ROLE_BOM, ROLE_FM];
  bytes32[] private _canEdit = [ROLE_ADMIN, ROLE_TM, ROLE_REP, ROLE_WSP, ROLE_BOM, ROLE_FM];

  string public _uiFieldDefinitionsHash;
  string public _Invoice;

  constructor(
    address gateKeeper,
    string memory Invoice,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public Secured(gateKeeper) {
    _Invoice = Invoice;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    setupStateMachine();
  }

  function canEdit() public view returns (bytes32[] memory) {
    return _canEdit;
  }

  /**
   * @notice Updates expense properties
   * @param Invoice It is the order Identification Number
   * @param ipfsFieldContainerHash ipfs hash of Warehouse metadata
   */
  function edit(string memory Invoice, string memory ipfsFieldContainerHash) public {
    _Invoice = Invoice;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  /**
   * @notice Returns a DID of the Warehouse
   * @dev Returns a unique DID (Decentralized Identifier) for the Warehouse.
   * @return string representing the DID of the Warehouse
   */
  function DID() public view returns (string memory) {
    return string(abi.encodePacked('did:demo:warehouse:', _Invoice));
  }

  /**
   * @notice Returns all the roles for this contract
   * @return bytes32[] array of raw bytes representing the roles
   */
  function getRoles() public view returns (bytes32[] memory) {
    return _roles;
  }

  function setupStateMachine() internal override {
    
    // CREATE STATES

    createState(STATE_INITIATED);
    createState(STATE_ARRIVED);
    createState(STATE_VERIFIED);
    createState(STATE_INSPECTED);
    createState(STATE_FAILED);
    createState(STATE_RETURNED);
    createState(STATE_OUT);
    createState(STATE_WEIGH);
    createState(STATE_WEIGH_SLIP);
    createState(STATE_MOVE_GODOWN);
    createState(STATE_UPLOAD_SLIP);
    createState(STATE_SAMPLE_COLLECT);
    createState(STATE_QUALITY_CHECK);
    createState(STATE_TARE_WEIGH);
    createState(STATE_GRN_ENTRY);
    createState(STATE_GRM_BRANCH);
    createState(STATE_GRN_VERIFIED);
    createState(STATE_GRN_FINANCE);
    createState(STATE_SAUDA_VERIFY);
    createState(STATE_SAUDA_FAILED);
    createState(STATE_GRN_REVERSAL);
    createState(STATE_GRN_NEW);
    createState(STATE_SAP_ENTRY);
    createState(STATE_CASH_DISCOUNT);
    createState(STATE_PAYMENT);
    createState(STATE_COMPLETE);
    
    setInitialState(STATE_INITIATED);

    // NEXT STATE

    addNextStateForState(STATE_INITIATED, STATE_ARRIVED);
    addNextStateForState(STATE_ARRIVED, STATE_VERIFIED);
    addNextStateForState(STATE_VERIFIED, STATE_INSPECTED);
    addNextStateForState(STATE_INSPECTED, STATE_WEIGH);
    addNextStateForState(STATE_WEIGH, STATE_WEIGH_SLIP);
    addNextStateForState(STATE_WEIGH_SLIP, STATE_MOVE_GODOWN);
    addNextStateForState(STATE_MOVE_GODOWN, STATE_UPLOAD_SLIP);
    addNextStateForState(STATE_UPLOAD_SLIP, STATE_SAMPLE_COLLECT);
    addNextStateForState(STATE_SAMPLE_COLLECT, STATE_QUALITY_CHECK);
    addNextStateForState(STATE_QUALITY_CHECK, STATE_TARE_WEIGH);
    addNextStateForState(STATE_TARE_WEIGH, STATE_GRN_ENTRY);
    addNextStateForState(STATE_GRN_ENTRY, STATE_GRM_BRANCH);
    addNextStateForState(STATE_GRM_BRANCH, STATE_GRN_VERIFIED);
    addNextStateForState(STATE_GRN_VERIFIED, STATE_GRN_FINANCE);
    addNextStateForState(STATE_GRN_FINANCE, STATE_SAUDA_VERIFY);
    addNextStateForState(STATE_SAUDA_VERIFY, STATE_SAP_ENTRY);
    addNextStateForState(STATE_SAP_ENTRY, STATE_CASH_DISCOUNT);
    addNextStateForState(STATE_CASH_DISCOUNT, STATE_PAYMENT);
    addNextStateForState(STATE_PAYMENT, STATE_COMPLETE);

    addNextStateForState(STATE_INSPECTED, STATE_FAILED);
    addNextStateForState(STATE_FAILED, STATE_RETURNED);
    addNextStateForState(STATE_RETURNED, STATE_OUT);

    addNextStateForState(STATE_SAUDA_VERIFY, STATE_SAUDA_FAILED);
    addNextStateForState(STATE_SAUDA_FAILED, STATE_GRN_REVERSAL);
    addNextStateForState(STATE_GRN_REVERSAL, STATE_GRN_NEW);
    addNextStateForState(STATE_GRN_NEW, STATE_GRN_VERIFIED); 

    addNextStateForState(STATE_SAP_ENTRY, STATE_PAYMENT);
    
    // EDIT 

    addAllowedFunctionForState(STATE_INITIATED, this.edit.selector);
    addAllowedFunctionForState(STATE_INSPECTED, this.edit.selector);
    addAllowedFunctionForState(STATE_GRN_ENTRY, this.edit.selector);
    addAllowedFunctionForState(STATE_GRN_NEW, this.edit.selector);
    addAllowedFunctionForState(STATE_RETURNED, this.edit.selector);

    // USER ROLES

    addRoleForState(STATE_INITIATED,ROLE_TM);
    addRoleForState(STATE_ARRIVED,ROLE_SEC);
    addRoleForState(STATE_VERIFIED,ROLE_REP);
    addRoleForState(STATE_INSPECTED,ROLE_REP);
    addRoleForState(STATE_FAILED,ROLE_SEC);
    addRoleForState(STATE_RETURNED,ROLE_SEC);
    addRoleForState(STATE_OUT,ROLE_TM);
    addRoleForState(STATE_WEIGH,ROLE_REP);
    addRoleForState(STATE_WEIGH_SLIP,ROLE_REP);
    addRoleForState(STATE_MOVE_GODOWN,ROLE_WSP);
    addRoleForState(STATE_UPLOAD_SLIP,ROLE_WSP);
    addRoleForState(STATE_SAMPLE_COLLECT,ROLE_WSP);
    addRoleForState(STATE_QUALITY_CHECK,ROLE_WSP);
    addRoleForState(STATE_TARE_WEIGH,ROLE_REP);
    addRoleForState(STATE_GRN_ENTRY,ROLE_REP);
    addRoleForState(STATE_GRM_BRANCH,ROLE_REP);
    addRoleForState(STATE_GRN_VERIFIED,ROLE_BOM);
    addRoleForState(STATE_GRN_FINANCE,ROLE_FM);
    addRoleForState(STATE_SAUDA_VERIFY,ROLE_FM);
    addRoleForState(STATE_SAUDA_FAILED,ROLE_FM);
    addRoleForState(STATE_GRN_REVERSAL,ROLE_BOM);
    addRoleForState(STATE_GRN_NEW,ROLE_BOM);
    addRoleForState(STATE_CASH_DISCOUNT,ROLE_FM);
    addRoleForState(STATE_PAYMENT,ROLE_FM);
    addRoleForState(STATE_COMPLETE,ROLE_FM);

    // ADMIN ROLES

    addRoleForState(STATE_INITIATED,ROLE_ADMIN);
    addRoleForState(STATE_ARRIVED,ROLE_ADMIN);
    addRoleForState(STATE_VERIFIED,ROLE_ADMIN);
    addRoleForState(STATE_INSPECTED,ROLE_ADMIN);
    addRoleForState(STATE_FAILED,ROLE_ADMIN);
    addRoleForState(STATE_RETURNED,ROLE_ADMIN);
    addRoleForState(STATE_OUT,ROLE_ADMIN);
    addRoleForState(STATE_WEIGH,ROLE_ADMIN);
    addRoleForState(STATE_WEIGH_SLIP,ROLE_ADMIN);
    addRoleForState(STATE_MOVE_GODOWN,ROLE_ADMIN);
    addRoleForState(STATE_UPLOAD_SLIP,ROLE_ADMIN);
    addRoleForState(STATE_SAMPLE_COLLECT,ROLE_ADMIN);
    addRoleForState(STATE_QUALITY_CHECK,ROLE_ADMIN);
    addRoleForState(STATE_TARE_WEIGH,ROLE_ADMIN);
    addRoleForState(STATE_GRN_ENTRY,ROLE_ADMIN);
    addRoleForState(STATE_GRM_BRANCH,ROLE_ADMIN);
    addRoleForState(STATE_GRN_VERIFIED,ROLE_ADMIN);
    addRoleForState(STATE_GRN_FINANCE,ROLE_ADMIN);
    addRoleForState(STATE_SAUDA_VERIFY,ROLE_ADMIN);
    addRoleForState(STATE_SAUDA_FAILED,ROLE_ADMIN);
    addRoleForState(STATE_GRN_REVERSAL,ROLE_ADMIN);
    addRoleForState(STATE_GRN_NEW,ROLE_ADMIN);
    addRoleForState(STATE_CASH_DISCOUNT,ROLE_ADMIN);
    addRoleForState(STATE_PAYMENT,ROLE_ADMIN);
    addRoleForState(STATE_COMPLETE,ROLE_ADMIN);
    
  }
}
