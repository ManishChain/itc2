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
pragma experimental ABIEncoderV2;

import '@settlemint/enteth-contracts/contracts/provenance/statemachine/FiniteStateMachine.sol';
import '@settlemint/enteth-contracts/contracts/authentication/Secured.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/IpfsFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/FileFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/utility/ui/UIFieldDefinitions.sol';
import '@settlemint/enteth-contracts/contracts/utility/conversions/Converter.sol';

/**
 * @title BillOfLading Contract
 */
contract BillOfLading is FiniteStateMachine, IpfsFieldContainer, FileFieldContainer, UIFieldDefinitions {
  bytes32 public constant UPGRADEABLE_REGISTRY_TARGET = 'UPGRADEABLE_REGISTRY_TARGET';
  bytes32 public constant CREATE_STATEMACHINE_ROLE = 'CREATE_STATEMACHINE_ROLE';

  /**
   * BillOfLading Events
   */
  event BillOfLadingCreated(uint256 fsmIndex, address owner, address registry);
  event BillOfLadingSubmitted(address owner, address expense, uint256 amount);
  event BillOfLadingSubmittedWithException(address owner, address expense, uint256 amount, string comment);
  event BillOfLadingReviewed(address owner, address expense, uint256 amount);
  event BillOfLadingNeedsUpdate(address owner, address expense, uint256 amount, string comment);
  event BillOfLadingAccepted(address owner, address expense, uint256 amount);
  event BillOfLadingRejected(address owner, address expense, uint256 amount, string comment);
  event BillOfLadingForceApproved(address owner, address expense, uint256 amount, string comment);
  event AmountChanged(address sender, uint256 fromAmount, uint256 toAmount);
  event ProofChanged(address sender, string fromProof, string toProof);

  /**
   * State Constants
   */
  bytes32 private constant STATE_PREPARED = 'PREPARED';
  bytes32 private constant STATE_PORT_OF_ORIGIN = 'PORT_OF_ORIGIN';
  bytes32 private constant STATE_IN_REVIEW = 'IN_REVIEW';
  bytes32 private constant STATE_INCOMPLETE = 'INCOMPLETE';
  bytes32 private constant STATE_EXCEPTION_GRANTED = 'EXCEPTION_GRANTED';
  bytes32 private constant STATE_CREATED = 'CREATED';
  bytes32 private constant STATE_IN_SHIPMENT = 'IN_SHIPMENT';
  bytes32 private constant STATE_PORT_OF_DESTINATION = 'PORT_OF_DESTINATION';
  bytes32 private constant STATE_RECEIVED = 'RECEIVED';

  /**
   * Role Constants
   */
  bytes32 private constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 private constant ROLE_CARRIER = 'ROLE_CARRIER';
  bytes32 private constant ROLE_CAPTAIN = 'ROLE_CAPTAIN';
  bytes32 private constant ROLE_FREIGHT_FORWARDER = 'ROLE_FREIGHT_FORWARDER';

  /**
   * BillOfLading states
   */
  bytes32[] public _allStates = [
    STATE_PREPARED,
    STATE_PORT_OF_ORIGIN,
    STATE_IN_REVIEW,
    STATE_INCOMPLETE,
    STATE_EXCEPTION_GRANTED,
    STATE_CREATED,
    STATE_IN_SHIPMENT,
    STATE_PORT_OF_DESTINATION,
    STATE_RECEIVED
  ];

  /**
   * BillOfLading roles
   */
  bytes32[] public _allRoles = [ROLE_ADMIN, ROLE_CAPTAIN, ROLE_CARRIER, ROLE_FREIGHT_FORWARDER];

  /**
   * BillOfLading helper role collection
   * specifies anyone who can edit an exponse
   */
  bytes32[] private _canEdit = [ROLE_ADMIN, ROLE_FREIGHT_FORWARDER];

  /**
   * The address of the upgradeable registry this contract belongs to.
   * Note that both this property together with the UPGRADEABLE_REGISTRY_TARGET const define a contract
   * that is part of an upgradeable registry and provides the link to the registry if required.
   */
  address public _upgradeableRegistry;

  /**
   * StateMachineMeta contains meta data for every StateMachine - seeing as struct are not composable
   * and the base StateMachine struct is defined in the FiniteStateMachine abstract there's no other
   * way to compose structs than having two separte arrays where the indices match.
   *
   * @dev Mint is aware of the above and will zip these two into a single struct so statemachines
   * from the outside will look as a composition of both StateMachine and StateMachineMeta structs.
   */
  StateMachineMeta[] internal _meta;

  /**
   * The index is a collection of DIDs for every state machine in the registry
   * Usually the getIndex call returns a list of contract addresses however as FSMs are
   * uniquely identified by their DID we return those instead
   */
  string[] internal _index;

  /**
   * @dev Struct defining an BillOfLading
   * @notice Gets decorated together with the StateMachine structs and forms the BillOfLading FSM
   */
  struct StateMachineMeta {
    string DID;
    string ipfsFieldContainerHash;
  }

  constructor(address gateKeeper, address registry) public Secured(gateKeeper) {
    require(registry != address(0x0), 'registry can not be zero');
    _upgradeableRegistry = registry;
  }

  //////
  // FSM Definition Functions
  //////

  /**
   * @notice Returns initial state
   */
  function initialState() public pure override returns (bytes32) {
    return STATE_PREPARED;
  }

  /**
   * @notice Returns all possible states
   */
  function allStates() public view override returns (bytes32[] memory) {
    return _allStates;
  }

  /**
   * @notice Returns all possible roles
   */
  function allRoles() public view override returns (bytes32[] memory) {
    return _allRoles;
  }

  /**
   * @notice Retrieve all possible next states for a certain state
   * @param state state
   */
  function getNextStatesForState(bytes32 state) public view override returns (bytes32[] memory test) {
    bytes32[] memory states;

    if (state == STATE_PREPARED) {
      states = new bytes32[](1);
      states[0] = STATE_PORT_OF_ORIGIN;
    }

    if (state == STATE_PORT_OF_ORIGIN) {
      states = new bytes32[](1);
      states[0] = STATE_IN_REVIEW;
    }

    if (state == STATE_IN_REVIEW) {
      states = new bytes32[](2);
      states[0] = STATE_INCOMPLETE;
      states[1] = STATE_CREATED;
    }

    if (state == STATE_INCOMPLETE) {
      states = new bytes32[](2);
      states[0] = STATE_PORT_OF_ORIGIN;
      states[1] = STATE_EXCEPTION_GRANTED;
    }

    if (state == STATE_EXCEPTION_GRANTED) {
      states = new bytes32[](1);
      states[0] = STATE_CREATED;
    }

    if (state == STATE_CREATED) {
      states = new bytes32[](1);
      states[0] = STATE_IN_SHIPMENT;
    }

    if (state == STATE_IN_SHIPMENT) {
      states = new bytes32[](1);
      states[0] = STATE_PORT_OF_DESTINATION;
    }

    if (state == STATE_PORT_OF_DESTINATION) {
      states = new bytes32[](1);
      states[0] = STATE_RECEIVED;
    }

    return states;
  }

  /**
   * @notice Retrieve all roles that are allowed to move it to the given state
   * @param state state
   */
  function getAllowedRolesForState(bytes32 state) public view override returns (bytes32[] memory) {
    bytes32[] memory roles;

    if (state == STATE_PREPARED || state == STATE_RECEIVED || state == STATE_PORT_OF_ORIGIN) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_FREIGHT_FORWARDER;
    } else if (state == STATE_EXCEPTION_GRANTED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_CAPTAIN;
    } else {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_CARRIER;
    }

    return roles;
  }

  /**
   * @notice Returns method signatures for functions which are allowed to execute in the given state
   * @param state state
   */
  function getAllowedFunctionsForState(bytes32 state) public view override returns (bytes4[] memory) {
    bytes4[] memory functions;

    if (
      state == STATE_PREPARED || state == STATE_PORT_OF_ORIGIN || state == STATE_IN_REVIEW || state == STATE_INCOMPLETE
    ) {
      functions = new bytes4[](1);
      functions[0] = this.edit.selector;
    }

    return functions;
  }

  /**
   * @notice Returns method signatures for functions that act as preconditions that must be met in order to transition to the given state
   * @param state state
   */
  function getPreconditionsForState(bytes32 state) public view override returns (bytes4[] memory) {}

  /**
   * @notice Returns method signatures for functions that will get called after transitioning to the given state
   * @param state state
   */
  function getCallbacksForState(bytes32 state) public view override returns (bytes4[] memory) {}

  /**
   * @notice Returns method signatures for functions that need to be called before transitioning to the given state
   * @param state state
   */
  function getPreFunctionForState(bytes32 state) public pure override returns (bytes4) {}

  //////
  // UI Field Definition Functions
  //////

  /**
   * @notice Set the UI field definition hash
   * @param uiFieldDefinitionsHash IPFS hash containing the UI field definitions JSON
   */
  function setUIFieldDefinitionsHash(string memory uiFieldDefinitionsHash)
    public
    override
    authWithCustomReason(UPDATE_UIFIELDDEFINITIONS_ROLE, 'Sender needs UPDATE_UIFIELDDEFINITIONS_ROLE')
  {
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
  }

  /**
   * @notice Returns the UI field definition hash
   */
  function getUIFieldDefinitionsHash() public view override returns (string memory) {
    return _uiFieldDefinitionsHash;
  }

  //////
  // Factory Functions
  //////

  /**
   * @notice Create a new statemachine
   * @param ipfsFieldContainerHash IPFS hash of the metadata fields
   */
  function create(string memory ipfsFieldContainerHash)
    public
    authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE')
  {
    _registry.push();
    StateMachine storage sm = _registry[_registry.length - 1];
    sm.currentState = initialState();
    sm.createdAt = now;
    sm.index = _registry.length - 1;

    _meta.push();
    StateMachineMeta storage meta = _meta[_meta.length - 1];
    meta.ipfsFieldContainerHash = ipfsFieldContainerHash;
    meta.DID = generateDID(_meta.length - 1);

    _index.push();
    _index[_index.length - 1] = meta.DID;

    emit BillOfLadingCreated(sm.index, msg.sender, _upgradeableRegistry);
  }

  /**
   * @notice Edit an existing statemachine
   * @param fsmIndex registry index of the statemachine struct
   * @param ipfsFieldContainerHash IPFS hash of the metadata fields
   */
  function edit(uint256 fsmIndex, string memory ipfsFieldContainerHash)
    public
    authManyWithCustomReason(_canEdit, 'Edit requires one of roles: ROLE_ADMIN, ROLE_CFP, ROLE_OB, ROLE_VDB')
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    _meta[fsmIndex].ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  function canEdit() public view returns (bytes32[] memory) {
    return _canEdit;
  }

  //////
  // Syncable Functions
  //////

  /**
   * @notice Returns the structs composing a statemachine for given index
   * @param fsmIndex state machine index
   */
  function getByIndex(uint256 fsmIndex) public view returns (StateMachine memory item, StateMachineMeta memory meta) {
    item = _registry[fsmIndex];
    meta = _meta[fsmIndex];
  }

  /**
   * @notice Returns all state machines structs in a single fetch
   */
  function getContents() public view returns (StateMachine[] memory registry, StateMachineMeta[] memory meta) {
    registry = _registry;
    meta = _meta;
  }

  /**
   * @notice Returns the (DID) index
   */
  function getIndex() public view returns (string[] memory index) {
    return _index;
  }

  //////
  // BillOfLading Functions
  //////

  /**
   * @notice Returns the preconditions for given state
   * @param state state
   * @dev Internal helper function that returns actual function pointers so a method can
   * loop those and effectively call the precondition function
   */
  function getPreconditionFunctionsForState(bytes32 state)
    internal
    view
    override
    returns (function(uint256, bytes32, bytes32) view[] memory)
  {}

  /**
   * @notice Returns the callbacks for given state
   * @param state state
   * @dev Internal helper function that returns actual function pointers so a method can
   * loop those and effectively call the callback function
   */
  function getCallbackFunctionsForState(bytes32 state)
    internal
    override
    returns (function(uint256, bytes32, bytes32) internal[] memory)
  {}

  //////
  // Helper Functions
  //////

  /**
   * @notice Generate state machine DID
   * @param fsmIndex state machine index
   */
  function generateDID(uint256 fsmIndex) internal view returns (string memory) {
    return
      string(abi.encodePacked('did:demo:billoflading:0x', addressToString(address(this)), ':', uintToString(fsmIndex)));
  }
}
