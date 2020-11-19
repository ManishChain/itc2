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

//TODO: Hoe Eigendom registreren op naam?

import '@settlemint/enteth-contracts/contracts/provenance/statemachine/StateMachine.sol';
import '@settlemint/enteth-contracts/contracts/authentication/Secured.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/IpfsFieldContainer.sol';

contract Plot is StateMachine, IpfsFieldContainer {
  event PlotOwnerShipTransfered(address indexed from, address indexed to, address indexed plot, string caPaKey);
  event PlotOwnershipTransferRefused(address indexed from, address indexed to, address indexed plot, string caPaKey);
  event PlotApproved(address indexed plot, address indexed owner, string indexed caPaKey);
  event PlotDisapproved(address indexed plot, address indexed owner, string indexed caPaKey);
  event PlotSplitApproved(address indexed plot, address indexed owner, string indexed caPaKey);
  event PloSplitRefused(address indexed plot, address indexed owner, string indexed caPaKey);

  bytes32 public constant STATE_PLOT_SUBMITTED = 'STATE_PLOT_SUBMITTED';
  bytes32 public constant STATE_PLOT_APPROVED = 'STATE_PLOT_APPROVED';
  bytes32 public constant STATE_PLOT_NEEDS_UPDATE = 'STATE_PLOT_NEEDS_UPDATE';
  bytes32 public constant STATE_PLOT_DISAPPROVED = 'STATE_PLOT_DISAPPROVED';
  bytes32 public constant STATE_PLOT_REVIEWED = 'STATE_PLOT_REVIEWED';
  bytes32 public constant STATE_TRANSFER_OWNER_REQUEST = 'STATE_TRANSFER_OWNER_REQUEST';
  bytes32 public constant STATE_TRANSFER_OWNER_REVIEWED = 'STATE_TRANSFER_OWNER_REVIEWED';
  bytes32 public constant STATE_TRANSFER_OWNER_NEEDS_UPD = 'STATE_TRANSFER_OWNER_NEEDS_UPD';
  bytes32 public constant STATE_TRANSFER_OWNER_DISAPPROV = 'STATE_TRANSFER_OWNER_DISAPPROV';
  bytes32 public constant STATE_SPLIT_REQUEST = 'STATE_SPLIT_REQUEST';
  bytes32 public constant STATE_SPLIT_REVIEWED = 'STATE_SPLIT_REVIEWED';
  bytes32 public constant STATE_SPLIT_NEEDS_UPDATE = 'STATE_SPLIT_NEEDS_UPDATE';
  bytes32 public constant STATE_SPLIT_APPROVED = 'STATE_SPLIT_APPROVED';
  bytes32 public constant STATE_SPLIT_DISAPPROVED = 'STATE_SPLIT_DISAPPROVED';

  bytes32 public constant ROLE_LAND_REGISTRAR = 'ROLE_LAND_REGISTRAR';
  bytes32 public constant ROLE_NOTARY = 'ROLE_NOTARY';
  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';

  bytes32[] public _roles = [ROLE_ADMIN, ROLE_LAND_REGISTRAR, ROLE_NOTARY];

  string public _uiFieldDefinitionsHash;
  address public _owner;
  string public _name;
  string public _caPaKey;
  string public _plotRejectionReason;
  string public _ownershipRejectionReason;
  string public _splitRejectionReason;

  constructor(
    address gateKeeper,
    string memory name,
    string memory caPaKey,
    address owner,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public Secured(gateKeeper) {
    _name = name;
    _caPaKey = caPaKey;
    _owner = owner;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    setupStateMachine();
  }

  function edit(
    string memory name,
    string memory caPaKey,
    address owner,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public {
    _name = name;
    _caPaKey = caPaKey;
    _owner = owner;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
  }

  function getRoles() public view returns (bytes32[] memory) {
    return _roles;
  }

  function setPlotNeedsUpdateRejectionReason(string memory rejectionReason) public checkAllowedFunction {
    setPlotRejectionReason(rejectionReason, STATE_PLOT_NEEDS_UPDATE);
  }

  function setPlotRejectedRejectionReason(string memory rejectionReason) public checkAllowedFunction {
    setPlotRejectionReason(rejectionReason, STATE_PLOT_DISAPPROVED);
  }

  function setTransferOwnershipRejectionReason(string memory rejectionReason) public checkAllowedFunction {
    setOwnerShipRejectionReason(rejectionReason, STATE_TRANSFER_OWNER_NEEDS_UPD);
  }

  function setSplitNeedsUpdateRejectionReason(string memory rejectionReason) public checkAllowedFunction {
    setPlotRejectionReason(rejectionReason, STATE_SPLIT_NEEDS_UPDATE);
  }

  function setSplitRejectedRejectionReason(string memory rejectionReason) public checkAllowedFunction {
    setPlotRejectionReason(rejectionReason, STATE_PLOT_APPROVED);
  }

  function DID() public view returns (string memory) {
    return string(abi.encodePacked('did:demo:plot:', _caPaKey));
  }

  function setupStateMachine() internal override {
    // Create all states
    createState(STATE_PLOT_SUBMITTED);
    createState(STATE_PLOT_APPROVED);
    createState(STATE_PLOT_NEEDS_UPDATE);
    createState(STATE_PLOT_DISAPPROVED);
    createState(STATE_PLOT_REVIEWED);
    createState(STATE_TRANSFER_OWNER_REQUEST);
    createState(STATE_TRANSFER_OWNER_REVIEWED);
    createState(STATE_TRANSFER_OWNER_NEEDS_UPD);
    createState(STATE_TRANSFER_OWNER_DISAPPROV);
    createState(STATE_SPLIT_REQUEST);
    createState(STATE_SPLIT_REVIEWED);
    createState(STATE_SPLIT_NEEDS_UPDATE);
    createState(STATE_SPLIT_APPROVED);
    createState(STATE_SPLIT_DISAPPROVED);

    // Add properties
    // STATE_PLOT_SUBMITTED
    addRoleForState(STATE_PLOT_SUBMITTED, ROLE_ADMIN);
    addRoleForState(STATE_PLOT_SUBMITTED, ROLE_NOTARY);
    addNextStateForState(STATE_PLOT_SUBMITTED, STATE_PLOT_REVIEWED);

    // STATE_PLOT_APPROVED
    addRoleForState(STATE_PLOT_APPROVED, ROLE_ADMIN);
    addRoleForState(STATE_PLOT_APPROVED, ROLE_LAND_REGISTRAR);
    addNextStateForState(STATE_PLOT_APPROVED, STATE_TRANSFER_OWNER_REQUEST);
    addNextStateForState(STATE_PLOT_APPROVED, STATE_SPLIT_REQUEST);

    // STATE_PLOT_NEEDS_UPDATE
    addRoleForState(STATE_PLOT_NEEDS_UPDATE, ROLE_ADMIN);
    addRoleForState(STATE_PLOT_NEEDS_UPDATE, ROLE_LAND_REGISTRAR);
    addNextStateForState(STATE_PLOT_NEEDS_UPDATE, STATE_PLOT_SUBMITTED);
    addPreConditionForState(STATE_PLOT_NEEDS_UPDATE, hasPlotRejectionReason);

    // STATE_PLOT_DISAPPROVED
    addRoleForState(STATE_PLOT_DISAPPROVED, ROLE_ADMIN);
    addRoleForState(STATE_PLOT_DISAPPROVED, ROLE_LAND_REGISTRAR);
    addPreConditionForState(STATE_PLOT_DISAPPROVED, hasPlotRejectionReason);

    // STATE_PLOT_REVIEWED
    addRoleForState(STATE_PLOT_REVIEWED, ROLE_ADMIN);
    addRoleForState(STATE_PLOT_REVIEWED, ROLE_LAND_REGISTRAR);
    addAllowedFunctionForState(STATE_PLOT_REVIEWED, this.setPlotNeedsUpdateRejectionReason.selector);
    addAllowedFunctionForState(STATE_PLOT_REVIEWED, this.setPlotRejectedRejectionReason.selector);
    addNextStateForState(STATE_PLOT_REVIEWED, STATE_PLOT_APPROVED);
    addNextStateForState(STATE_PLOT_REVIEWED, STATE_PLOT_NEEDS_UPDATE);
    addNextStateForState(STATE_PLOT_REVIEWED, STATE_PLOT_DISAPPROVED);

    // STATE_TRANSFER_OWNER_REQUEST
    addRoleForState(STATE_TRANSFER_OWNER_REQUEST, ROLE_ADMIN);
    addRoleForState(STATE_TRANSFER_OWNER_REQUEST, ROLE_NOTARY);
    addNextStateForState(STATE_TRANSFER_OWNER_REQUEST, STATE_TRANSFER_OWNER_REVIEWED);

    // STATE_TRANSFER_OWNER_REVIEWED
    addRoleForState(STATE_TRANSFER_OWNER_REVIEWED, ROLE_ADMIN);
    addRoleForState(STATE_TRANSFER_OWNER_REVIEWED, ROLE_LAND_REGISTRAR);
    addAllowedFunctionForState(STATE_TRANSFER_OWNER_REVIEWED, this.setTransferOwnershipRejectionReason.selector);
    addNextStateForState(STATE_TRANSFER_OWNER_REVIEWED, STATE_TRANSFER_OWNER_NEEDS_UPD);
    addNextStateForState(STATE_TRANSFER_OWNER_REVIEWED, STATE_TRANSFER_OWNER_DISAPPROV);

    // STATE_TRANSFER_OWNER_NEEDS_UPD
    addRoleForState(STATE_TRANSFER_OWNER_NEEDS_UPD, ROLE_ADMIN);
    addRoleForState(STATE_TRANSFER_OWNER_NEEDS_UPD, ROLE_LAND_REGISTRAR);
    addNextStateForState(STATE_TRANSFER_OWNER_NEEDS_UPD, STATE_TRANSFER_OWNER_REQUEST);
    addNextStateForState(STATE_TRANSFER_OWNER_NEEDS_UPD, STATE_PLOT_APPROVED);
    addPreConditionForState(STATE_TRANSFER_OWNER_NEEDS_UPD, hasOwnershipRejectionReason);

    // STATE_TRANSFER_OWNER_DISAPPROV
    addRoleForState(STATE_TRANSFER_OWNER_DISAPPROV, ROLE_ADMIN);
    addRoleForState(STATE_TRANSFER_OWNER_DISAPPROV, ROLE_LAND_REGISTRAR);
    addNextStateForState(STATE_TRANSFER_OWNER_DISAPPROV, STATE_PLOT_APPROVED);
    addPreConditionForState(STATE_TRANSFER_OWNER_DISAPPROV, hasOwnershipRejectionReason);

    // STATE_SPLIT_REQUEST
    addRoleForState(STATE_SPLIT_REQUEST, ROLE_ADMIN);
    addRoleForState(STATE_SPLIT_REQUEST, ROLE_NOTARY);
    addNextStateForState(STATE_SPLIT_REQUEST, STATE_SPLIT_REVIEWED);

    // STATE_SPLIT_REVIEWED
    addRoleForState(STATE_SPLIT_REVIEWED, ROLE_ADMIN);
    addRoleForState(STATE_SPLIT_REVIEWED, ROLE_LAND_REGISTRAR);
    addAllowedFunctionForState(STATE_SPLIT_REVIEWED, this.setPlotNeedsUpdateRejectionReason.selector);
    addAllowedFunctionForState(STATE_SPLIT_REVIEWED, this.setPlotRejectedRejectionReason.selector);
    addNextStateForState(STATE_SPLIT_REVIEWED, STATE_SPLIT_NEEDS_UPDATE);
    addNextStateForState(STATE_SPLIT_REVIEWED, STATE_SPLIT_APPROVED);
    addNextStateForState(STATE_SPLIT_REVIEWED, STATE_SPLIT_DISAPPROVED);

    // STATE_SPLIT_NEEDS_UPDATE
    addRoleForState(STATE_SPLIT_NEEDS_UPDATE, ROLE_ADMIN);
    addRoleForState(STATE_SPLIT_NEEDS_UPDATE, ROLE_LAND_REGISTRAR);
    addPreConditionForState(STATE_SPLIT_NEEDS_UPDATE, hasSplittRejectionReason);
    addNextStateForState(STATE_SPLIT_NEEDS_UPDATE, STATE_SPLIT_REQUEST);
    addNextStateForState(STATE_SPLIT_NEEDS_UPDATE, STATE_PLOT_APPROVED);

    // STATE_SPLIT_APPROVED
    // Once a plot has been split it cannot be used again
    addRoleForState(STATE_SPLIT_APPROVED, ROLE_ADMIN);
    addRoleForState(STATE_SPLIT_APPROVED, ROLE_LAND_REGISTRAR);

    // STATE_SPLIT_DISAPPROVED
    addRoleForState(STATE_SPLIT_DISAPPROVED, ROLE_ADMIN);
    addRoleForState(STATE_SPLIT_DISAPPROVED, ROLE_LAND_REGISTRAR);
    addPreConditionForState(STATE_SPLIT_DISAPPROVED, hasSplittRejectionReason);
    addNextStateForState(STATE_SPLIT_DISAPPROVED, STATE_PLOT_APPROVED);

    setInitialState(STATE_PLOT_SUBMITTED);
  }

  /**
   * Precondition functions
   */
  function hasPlotRejectionReason(
    bytes32, /* fromState */
    bytes32 /*toState*/
  ) internal view {
    bytes memory reasonForRejection = bytes(_plotRejectionReason);
    require(reasonForRejection.length > 0, 'A reason for a rejection is required');
  }

  function setPlotRejectionReason(string memory rejectionReason, bytes32 nextState) private {
    bytes memory bytesRejectionReason = bytes(_plotRejectionReason);
    require(bytesRejectionReason.length > 0, 'The rejection reason is required');
    _plotRejectionReason = rejectionReason;
    transitionState(nextState);
  }

  function hasOwnershipRejectionReason(
    bytes32, /* fromState */
    bytes32 /*toState*/
  ) internal view {
    bytes memory reasonForRejection = bytes(_ownershipRejectionReason);
    require(reasonForRejection.length > 0, 'A reason for a rejection is required');
  }

  function setOwnerShipRejectionReason(string memory rejectionReason, bytes32 nextState) private {
    bytes memory bytesRejectionReason = bytes(_ownershipRejectionReason);
    require(bytesRejectionReason.length > 0, 'The rejection reason is required');
    _ownershipRejectionReason = rejectionReason;
    transitionState(nextState);
  }

  function hasSplittRejectionReason(
    bytes32, /* fromState */
    bytes32 /*toState*/
  ) internal view {
    bytes memory reasonForRejection = bytes(_splitRejectionReason);
    require(reasonForRejection.length > 0, 'A reason for a rejection is required');
  }

  function setSplitRejectionReason(string memory rejectionReason, bytes32 nextState) private {
    bytes memory bytesRejectionReason = bytes(_splitRejectionReason);
    require(bytesRejectionReason.length > 0, 'The rejection reason is required');
    _splitRejectionReason = rejectionReason;
    transitionState(nextState);
  }
}
