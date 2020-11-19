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
 * DrugPackage
 *
 * A drug package exists of
 *  - a description of the drug in the package where a DrugPackage is defined as a chemical or biologic
 *    substance, used as a medical therapy, that has a physiological effect on an organism and the
 *    schema for it as defined by https://schema.org/DrugPackage
 *  - a serialized National Drug Code (sNDC) of the individual package containing the labeler code,
 *    product code, package code and a unique serial number for this packet. The definition of this
 *    sNDC by the FDA is as follows: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/standards-securing-drug-supply-chain-standardized-numerical-identification-prescription-drug
 *    A slight variation is applied here where the sNDC is modified to comply with the Decentralized ID
 *    standard defined here: https://w3c-ccg.github.io/did-spec/
 *
 * @title State machine to track a drug package
 */
contract DrugPackage is Converter, StateMachine, IpfsFieldContainer, FileFieldContainer {
  bytes32 public constant STATE_PACKAGED_LABELED = 'STATE_PACKAGED_LABELED';
  bytes32 public constant STATE_IN_TRANSIT_M2R = 'STATE_IN_TRANSIT_M2R';
  bytes32 public constant STATE_AT_RESELLER = 'STATE_AT_RESELLER';
  bytes32 public constant STATE_IN_TRANSIT_R2P = 'STATE_IN_TRANSIT_R2P';
  bytes32 public constant STATE_IN_TRANSIT_R2R = 'STATE_IN_TRANSIT_R2R';
  bytes32 public constant STATE_AT_PHARMACY = 'STATE_AT_PHARMACY';
  bytes32 public constant STATE_FULLFILLED_TO_PATIENT = 'STATE_FULLFILLED_TO_PATIENT';

  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_MANUFACTURER = 'ROLE_MANUFACTURER';
  bytes32 public constant ROLE_RESELLER = 'ROLE_RESELLER';
  bytes32 public constant ROLE_PHARMACY = 'ROLE_PHARMACY';

  bytes32[] public _roles = [ROLE_ADMIN, ROLE_MANUFACTURER, ROLE_RESELLER, ROLE_PHARMACY];

  string public _uiFieldDefinitionsHash;
  string public _labellerCode;
  string public _productCode;
  string public _packageCode;

  constructor(
    address gateKeeper,
    string memory labellerCode,
    string memory productCode,
    string memory packageCode,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public Secured(gateKeeper) {
    _labellerCode = labellerCode;
    _productCode = productCode;
    _packageCode = packageCode;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    setupStateMachine();
  }

  /**
   * @notice Updates drug package properties
   * @param labellerCode new labeller code
   * @param productCode new product code
   * @param packageCode new package code
   * @param ipfsFieldContainerHash new hash for the drug package metadata
   */
  function edit(
    string memory labellerCode,
    string memory productCode,
    string memory packageCode,
    string memory ipfsFieldContainerHash
  ) public {
    _labellerCode = labellerCode;
    _productCode = productCode;
    _packageCode = packageCode;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  /**
   * @notice Returns a DID of the expense.
   * @dev Returns a unique DID (Decentralized Identifier) for the expense.
   * @return string representing the DID of the expense
   */
  function DID() public view returns (string memory) {
    return
      string(
        abi.encodePacked(
          'did:demo:pharmapack:',
          _labellerCode,
          _productCode,
          _packageCode,
          addressToString(address(this))
        )
      );
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
    createState(STATE_PACKAGED_LABELED);
    createState(STATE_IN_TRANSIT_M2R);
    createState(STATE_AT_RESELLER);
    createState(STATE_IN_TRANSIT_R2R);
    createState(STATE_IN_TRANSIT_R2P);
    createState(STATE_AT_PHARMACY);
    createState(STATE_FULLFILLED_TO_PATIENT);

    // add properties
    // STATE_PACKAGED_LABELED
    addNextStateForState(STATE_PACKAGED_LABELED, STATE_IN_TRANSIT_M2R);

    // STATE_IN_TRANSIT_M2R
    addRoleForState(STATE_IN_TRANSIT_M2R, ROLE_ADMIN);
    addRoleForState(STATE_IN_TRANSIT_M2R, ROLE_MANUFACTURER);
    addNextStateForState(STATE_IN_TRANSIT_M2R, STATE_AT_RESELLER);

    // STATE_AT_RESELLER
    addRoleForState(STATE_AT_RESELLER, ROLE_ADMIN);
    addRoleForState(STATE_AT_RESELLER, ROLE_RESELLER);
    addNextStateForState(STATE_AT_RESELLER, STATE_IN_TRANSIT_R2R);
    addNextStateForState(STATE_AT_RESELLER, STATE_IN_TRANSIT_R2P);

    // STATE_IN_TRANSIT_R2R
    addRoleForState(STATE_IN_TRANSIT_R2R, ROLE_ADMIN);
    addRoleForState(STATE_IN_TRANSIT_R2R, ROLE_RESELLER);
    addNextStateForState(STATE_IN_TRANSIT_R2R, STATE_AT_RESELLER);

    // STATE_IN_TRANSIT_R2R
    addRoleForState(STATE_IN_TRANSIT_R2P, ROLE_ADMIN);
    addRoleForState(STATE_IN_TRANSIT_R2P, ROLE_RESELLER);
    addNextStateForState(STATE_IN_TRANSIT_R2P, STATE_AT_PHARMACY);

    // STATE_IN_TRANSIT_R2R
    addRoleForState(STATE_AT_PHARMACY, ROLE_ADMIN);
    addRoleForState(STATE_AT_PHARMACY, ROLE_PHARMACY);
    addNextStateForState(STATE_AT_PHARMACY, STATE_FULLFILLED_TO_PATIENT);

    addRoleForState(STATE_FULLFILLED_TO_PATIENT, ROLE_ADMIN);
    addRoleForState(STATE_FULLFILLED_TO_PATIENT, ROLE_PHARMACY);

    setInitialState(STATE_PACKAGED_LABELED);
  }
}
