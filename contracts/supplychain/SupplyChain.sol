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
 * SupplyChain

 *
 * @title State machine for SupplyChain
 */
contract SupplyChain is Converter, StateMachine, IpfsFieldContainer, FileFieldContainer {
  bytes32 public constant STATE_DEMAND_GENERATED = 'DEMAND GENERATED';
  bytes32 public constant STATE_ORDER_PLACED = 'ORDER PLACED';
  bytes32 public constant STATE_ORDER_ACCEPTED = 'ACCEPTED';
  bytes32 public constant STATE_ORDER_ON_HOLD = 'ON HOLD';
  bytes32 public constant STATE_ORDER_DECLINED = 'DECLINED';

  bytes32 public constant STATE_IN_PRODUCTION = 'IN PRODUCTION';
  bytes32 public constant STATE_READY_FOR_DISPATCH = 'READY FOR DISPATCH';
  bytes32 public constant STATE_REACHED_TRANSFER_POINT = 'AT TRANSFER POINT';

  bytes32 public constant STATE_RECEIEVED_AT_WAREHOUSE = 'RECIEVED AT WAREHOUSE';
  bytes32 public constant STATE_STOCKED_AT_WAREHOUSE = 'STOCKED AT WAREHOUSE';
  bytes32 public constant STATE_OUT_FOR_DELIVERY = 'OUT FOR DELIVERY';
  bytes32 public constant STATE_RECIEVED_BY_BUYER = 'RECIEVED BY BUYER';
  bytes32 public constant STATE_PRODUCT_SHELVED = 'SHELVED';
  bytes32 public constant STATE_PRODUCT_SOLD = 'SOLD';
  bytes32 public constant STATE_PRODUCT_DISCARDED = 'DISCARDED';

  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_BUYER = 'ROLE_BUYER';
  bytes32 public constant ROLE_SUPPLIER = 'ROLE_SUPPLIER';
  bytes32 public constant ROLE_TRANSPORTER = 'ROLE_TRANSPORTER';
  bytes32 public constant ROLE_WAREHOUSE = 'ROLE_WAREHOUSE';

  bytes32[] public _roles = [ROLE_ADMIN, ROLE_BUYER, ROLE_SUPPLIER, ROLE_TRANSPORTER];

  string public _uiFieldDefinitionsHash;
  string public _Order_Number;

  constructor(
    address gateKeeper,
    string memory Order_Number,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public Secured(gateKeeper) {
    _Order_Number = Order_Number;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    setupStateMachine();
  }

  /**
   * @notice Updates expense properties
   * @param Order_Number It is the order Identification Number
   * @param ipfsFieldContainerHash ipfs hash of supplychainfinance metadata
   */
  function edit(string memory Order_Number, string memory ipfsFieldContainerHash) public {
    _Order_Number = Order_Number;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  /**
   * @notice Returns a DID of the supplychainfinance
   * @dev Returns a unique DID (Decentralized Identifier) for the supplychainfinance.
   * @return string representing the DID of the supplychainfinance
   */
  function DID() public view returns (string memory) {
    return string(abi.encodePacked('did:demo:supplychainfinance:', _Order_Number));
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

    createState(STATE_DEMAND_GENERATED);
    createState(STATE_ORDER_PLACED);
    createState(STATE_ORDER_ACCEPTED);
    createState(STATE_ORDER_ON_HOLD);
    createState(STATE_ORDER_DECLINED);
    createState(STATE_IN_PRODUCTION);
    createState(STATE_READY_FOR_DISPATCH);
    createState(STATE_REACHED_TRANSFER_POINT);
    createState(STATE_RECEIEVED_AT_WAREHOUSE);
    createState(STATE_STOCKED_AT_WAREHOUSE);
    createState(STATE_OUT_FOR_DELIVERY);
    createState(STATE_RECIEVED_BY_BUYER);
    createState(STATE_PRODUCT_SHELVED);
    createState(STATE_PRODUCT_SOLD);
    createState(STATE_PRODUCT_DISCARDED);

    // add properties

    addNextStateForState(STATE_DEMAND_GENERATED, STATE_ORDER_PLACED);
    addNextStateForState(STATE_ORDER_PLACED, STATE_ORDER_ACCEPTED);
    addNextStateForState(STATE_ORDER_PLACED, STATE_ORDER_ON_HOLD);
    addNextStateForState(STATE_ORDER_PLACED, STATE_ORDER_DECLINED);
    addNextStateForState(STATE_ORDER_ACCEPTED, STATE_IN_PRODUCTION);
    addNextStateForState(STATE_IN_PRODUCTION, STATE_READY_FOR_DISPATCH);
    addNextStateForState(STATE_READY_FOR_DISPATCH, STATE_REACHED_TRANSFER_POINT);
    addNextStateForState(STATE_REACHED_TRANSFER_POINT, STATE_RECEIEVED_AT_WAREHOUSE);
    addNextStateForState(STATE_RECEIEVED_AT_WAREHOUSE, STATE_STOCKED_AT_WAREHOUSE);
    addNextStateForState(STATE_STOCKED_AT_WAREHOUSE, STATE_OUT_FOR_DELIVERY);
    addNextStateForState(STATE_OUT_FOR_DELIVERY, STATE_RECIEVED_BY_BUYER);
    addNextStateForState(STATE_RECIEVED_BY_BUYER, STATE_PRODUCT_SHELVED);
    addNextStateForState(STATE_RECIEVED_BY_BUYER, STATE_PRODUCT_SOLD);
    addNextStateForState(STATE_RECIEVED_BY_BUYER, STATE_PRODUCT_DISCARDED);

    addRoleForState(STATE_DEMAND_GENERATED, ROLE_BUYER);
    addRoleForState(STATE_ORDER_PLACED, ROLE_BUYER);
    addRoleForState(STATE_ORDER_ACCEPTED, ROLE_SUPPLIER);
    addRoleForState(STATE_ORDER_ON_HOLD, ROLE_SUPPLIER);
    addRoleForState(STATE_ORDER_DECLINED, ROLE_SUPPLIER);
    addRoleForState(STATE_IN_PRODUCTION, ROLE_SUPPLIER);
    addRoleForState(STATE_READY_FOR_DISPATCH, ROLE_SUPPLIER);
    addRoleForState(STATE_REACHED_TRANSFER_POINT, ROLE_TRANSPORTER);
    addRoleForState(STATE_RECEIEVED_AT_WAREHOUSE, ROLE_WAREHOUSE);
    addRoleForState(STATE_STOCKED_AT_WAREHOUSE, ROLE_WAREHOUSE);
    addRoleForState(STATE_OUT_FOR_DELIVERY, ROLE_TRANSPORTER);
    addRoleForState(STATE_RECIEVED_BY_BUYER, ROLE_BUYER);
    addRoleForState(STATE_PRODUCT_SHELVED, ROLE_BUYER);
    addRoleForState(STATE_PRODUCT_SOLD, ROLE_BUYER);
    addRoleForState(STATE_PRODUCT_DISCARDED, ROLE_BUYER);
    addRoleForState(STATE_DEMAND_GENERATED, ROLE_ADMIN);
    addRoleForState(STATE_ORDER_PLACED, ROLE_ADMIN);
    addRoleForState(STATE_ORDER_ACCEPTED, ROLE_ADMIN);
    addRoleForState(STATE_ORDER_ON_HOLD, ROLE_ADMIN);
    addRoleForState(STATE_ORDER_DECLINED, ROLE_ADMIN);
    addRoleForState(STATE_IN_PRODUCTION, ROLE_ADMIN);
    addRoleForState(STATE_READY_FOR_DISPATCH, ROLE_ADMIN);
    addRoleForState(STATE_REACHED_TRANSFER_POINT, ROLE_ADMIN);
    addRoleForState(STATE_RECEIEVED_AT_WAREHOUSE, ROLE_ADMIN);
    addRoleForState(STATE_STOCKED_AT_WAREHOUSE, ROLE_ADMIN);
    addRoleForState(STATE_OUT_FOR_DELIVERY, ROLE_ADMIN);
    addRoleForState(STATE_RECIEVED_BY_BUYER, ROLE_ADMIN);
    addRoleForState(STATE_PRODUCT_SHELVED, ROLE_ADMIN);
    addRoleForState(STATE_PRODUCT_SOLD, ROLE_ADMIN);
    addRoleForState(STATE_PRODUCT_DISCARDED, ROLE_ADMIN);

    setInitialState(STATE_DEMAND_GENERATED);
  }
}
