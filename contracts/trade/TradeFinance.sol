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
 * TradeFinance

 *
 * @title State machine for TradeFinance
 */
contract TradeFinance is Converter, StateMachine, IpfsFieldContainer, FileFieldContainer {
  bytes32 public constant STATE_1 = 'REQUEST_GENERATED';
  bytes32 public constant STATE_2A = 'INITIATE_L1';
  bytes32 public constant STATE_2B = 'INITIATE_L2';
  bytes32 public constant STATE_2C = 'INITIATE_L3';
  bytes32 public constant STATE_3A = 'SMALL_L1';
  bytes32 public constant STATE_4A = 'MEDIUM_L1';
  bytes32 public constant STATE_4B = 'MEDIUM_L2';
  bytes32 public constant STATE_5A = 'LARGE_L1';
  bytes32 public constant STATE_5B = 'LARGE_L2';
  bytes32 public constant STATE_5C = 'LARGE_L3';
  bytes32 public constant STATE_6 = 'READY_FOR_SENDING';
  bytes32 public constant STATE_7 = 'SENT_TO_BANK';
  bytes32 public constant STATE_8 = 'ACKNOWLEDGED';

  
  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_MAKER = 'ROLE_MAKER';
  bytes32 public constant ROLE_BANK = 'ROLE_BANK';
  bytes32 public constant ROLE_L1APPROVER = 'ROLE_L1';
  bytes32 public constant ROLE_L2APPROVER = 'ROLE_L2';
  bytes32 public constant ROLE_L3APPROVER = 'ROLE_L3';
  bytes32 public constant ROLE_REQUESTER = 'ROLE_REQUESTER';
  bytes32 public constant ROLE_USER = 'ROLE_USER';


  bytes32[] public _roles = [ROLE_ADMIN,ROLE_USER, ROLE_MAKER, ROLE_BANK, ROLE_L1APPROVER, ROLE_L2APPROVER, ROLE_L3APPROVER, ROLE_REQUESTER];

  string public _uiFieldDefinitionsHash;
  string public _SAP_Number;
  string public _Bank;
  string public _Date;
  string public _Value;
  string public _Beneficiary;
 

  constructor(
    address gateKeeper,
    string memory SAP_Number,
    string memory Bank,
    string memory Date,
    string memory Value,
    string memory Beneficiary,



    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public Secured(gateKeeper) {
    _SAP_Number = SAP_Number;
    _Bank = Bank;
    _Date = Date;
    _Value = Value;
    _Beneficiary = Beneficiary;

    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    setupStateMachine();
  }

  /**
   * @notice Updates expense properties
   * @param SAP_Number It is the order Identification Number
   * @param ipfsFieldContainerHash ipfs hash of tradefinance metadata
   */
  function edit(string memory SAP_Number, string memory Bank, string memory Date,  string memory Value,  string memory Beneficiary, string memory ipfsFieldContainerHash) public {
    _SAP_Number = SAP_Number;
    _Bank = Bank;
    _Date = Date;
    _Value = Value;
    _Beneficiary = Beneficiary;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  /**
   * @notice Returns a DID of the tradefinance
   * @dev Returns a unique DID (Decentralized Identifier) for the tradefinance.
   * @return string representing the DID of the tradefinance
   */
  function DID() public view returns (string memory) {
    return string(abi.encodePacked('did:demo:tradefinance:', _SAP_Number));
  }

  /**
   * @notice Returns all the roles for this contract
   * @return bytes32[] array of raw bytes representing the roles
   */
  function getRoles() public view returns (bytes32[] memory) {
    return _roles;
  }

  bytes32[] private _canEdit = [
    ROLE_ADMIN

  ];

  function canEdit() public view returns (bytes32[] memory) {
    return _canEdit;
  }

  function setupStateMachine() internal override {
    //create all states

    createState(STATE_1);
    createState(STATE_2A);
    createState(STATE_2B);
    createState(STATE_2C);
    createState(STATE_3A);
    createState(STATE_4A);
    createState(STATE_4B);
    createState(STATE_5A);
    createState(STATE_5B);
    createState(STATE_5C);
    createState(STATE_6);
    createState(STATE_7);
    createState(STATE_8);


    // add properties

    addNextStateForState(STATE_1, STATE_2A);
    addNextStateForState(STATE_1, STATE_2B);
    addNextStateForState(STATE_1, STATE_2C);
    addNextStateForState(STATE_2A, STATE_3A);
    addNextStateForState(STATE_2B, STATE_4A);
    addNextStateForState(STATE_2C, STATE_5A);
    addNextStateForState(STATE_3A, STATE_6);
    addNextStateForState(STATE_4A, STATE_4B);
    addNextStateForState(STATE_4B, STATE_6);
    addNextStateForState(STATE_5A, STATE_5B);
    addNextStateForState(STATE_5B, STATE_5C);
    addNextStateForState(STATE_5C, STATE_6);

    addNextStateForState(STATE_6, STATE_7);
    addNextStateForState(STATE_7, STATE_8);
    
    addRoleForState(STATE_1, ROLE_MAKER);
    addRoleForState(STATE_2A, ROLE_MAKER);
    addRoleForState(STATE_2B, ROLE_MAKER);
    addRoleForState(STATE_2C, ROLE_MAKER);
    addRoleForState(STATE_3A, ROLE_L1APPROVER);
    addRoleForState(STATE_4A, ROLE_L1APPROVER);
    addRoleForState(STATE_5A, ROLE_L1APPROVER);
    addRoleForState(STATE_4B, ROLE_L2APPROVER);
    addRoleForState(STATE_5B, ROLE_L2APPROVER);
    addRoleForState(STATE_5C, ROLE_L3APPROVER);
    addRoleForState(STATE_6, ROLE_L1APPROVER);
    addRoleForState(STATE_6, ROLE_L2APPROVER);
    addRoleForState(STATE_6, ROLE_L3APPROVER);
    addRoleForState(STATE_7, ROLE_REQUESTER);
    addRoleForState(STATE_8, ROLE_BANK);
    
    addRoleForState(STATE_1, ROLE_ADMIN);
    addRoleForState(STATE_2A, ROLE_ADMIN);
    addRoleForState(STATE_2B, ROLE_ADMIN);
    addRoleForState(STATE_2C, ROLE_ADMIN);
    addRoleForState(STATE_3A, ROLE_ADMIN);
    addRoleForState(STATE_4A, ROLE_ADMIN);
    addRoleForState(STATE_5A, ROLE_ADMIN);
    addRoleForState(STATE_4B, ROLE_ADMIN);
    addRoleForState(STATE_5B, ROLE_ADMIN);
    addRoleForState(STATE_5C, ROLE_ADMIN);
    addRoleForState(STATE_6, ROLE_ADMIN);
    addRoleForState(STATE_6, ROLE_ADMIN);
    addRoleForState(STATE_6, ROLE_ADMIN);
    addRoleForState(STATE_7, ROLE_ADMIN);
    addRoleForState(STATE_8, ROLE_ADMIN);

    addRoleForState(STATE_1, ROLE_USER);
    addRoleForState(STATE_2A, ROLE_USER);
    addRoleForState(STATE_2B, ROLE_USER);
    addRoleForState(STATE_2C, ROLE_USER);
    addRoleForState(STATE_3A, ROLE_USER);
    addRoleForState(STATE_4A, ROLE_USER);
    addRoleForState(STATE_5A, ROLE_USER);
    addRoleForState(STATE_4B, ROLE_USER);
    addRoleForState(STATE_5B, ROLE_USER);
    addRoleForState(STATE_5C, ROLE_USER);
    addRoleForState(STATE_6, ROLE_USER);
    addRoleForState(STATE_6, ROLE_USER);
    addRoleForState(STATE_6, ROLE_USER);
    addRoleForState(STATE_7, ROLE_USER);
    addRoleForState(STATE_8, ROLE_USER);

    setInitialState(STATE_1);
  }
}
