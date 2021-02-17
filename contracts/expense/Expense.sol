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
 * @title Expense Contract
 */
contract Expense is FiniteStateMachine, IpfsFieldContainer, FileFieldContainer, UIFieldDefinitions {
  bytes32 public constant UPGRADEABLE_REGISTRY_TARGET = 'UPGRADEABLE_REGISTRY_TARGET';
  bytes32 public constant CREATE_STATEMACHINE_ROLE = 'CREATE_STATEMACHINE_ROLE';

  /**
   * Expense Events
   */
  event ExpenseCreated(uint256 fsmIndex, address owner, address registry);
  event ExpenseSubmitted(address owner, address expense, uint256 amount);
  event ExpenseSubmittedWithException(address owner, address expense, uint256 amount, string comment);
  event ExpenseReviewed(address owner, address expense, uint256 amount);
  event ExpenseNeedsUpdate(address owner, address expense, uint256 amount, string comment);
  event ExpenseAccepted(address owner, address expense, uint256 amount);
  event ExpenseRejected(address owner, address expense, uint256 amount, string comment);
  event ExpenseForceApproved(address owner, address expense, uint256 amount, string comment);
  event AmountChanged(address sender, uint256 fromAmount, uint256 toAmount);
  event ProofChanged(address sender, string fromProof, string toProof);

  /**
   * State Constants
   *
   * DRAFT = the expense is added, possibly with missing info
   * SUBMITTED = submitted to the OB for review, all precoditions are met
   * SUBMITTED_WITH_EXCEPTION = submitted expense does not meet all preconditions
   * REVIEWED = the OB has reviewed the invoice
   * NEEDS_UPDATE = the OB has sent the invoice back to the CFP for modification
   * APPROVED = VDB approves the invoice out of REVIEWED
   * REJECTED = VDB (or DGD) rejects the invoice out of reviewed (a comment is required)
   * FORCE_APPROVED = VDB approves the invoice out of REVIEWED even of it is not ok
   */
  bytes32 private constant STATE_DRAFT = 'DRAFT';
  bytes32 private constant STATE_SUBMITTED = 'SUBMITTED';
  bytes32 private constant STATE_SUBMITTED_WITH_EXCEPTION = 'SUBMITTED_WITH_EXCEPTION';
  bytes32 private constant STATE_REVIEWED = 'REVIEWED';
  bytes32 private constant STATE_NEEDS_UPDATE = 'NEEDS_UPDATE';
  bytes32 private constant STATE_APPROVED = 'APPROVED';
  bytes32 private constant STATE_REJECTED = 'REJECTED';
  bytes32 private constant STATE_FORCE_APPROVED = 'FORCE_APPROVED';

  /**
   * Role Constants
   */
  bytes32 private constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 private constant ROLE_REVISOR = 'ROLE_REVISOR';
  bytes32 private constant ROLE_USER = 'ROLE_USER';

  /**
   * Expense states
   */
  bytes32[] public _allStates = [
    STATE_DRAFT,
    STATE_SUBMITTED,
    STATE_SUBMITTED_WITH_EXCEPTION,
    STATE_REVIEWED,
    STATE_NEEDS_UPDATE,
    STATE_APPROVED,
    STATE_REJECTED,
    STATE_FORCE_APPROVED
  ];

  /**
   * Expense roles
   */
  bytes32[] public _allRoles = [ROLE_ADMIN, ROLE_REVISOR, ROLE_USER];

  /**
   * Expense helper role collection
   * specifies anyone who can edit an exponse
   */
  bytes32[] private _canEdit = [ROLE_ADMIN, ROLE_USER];

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
   * @dev Struct defining an Expense
   * @notice Gets decorated together with the StateMachine structs and forms the Expense FSM
   */
  struct StateMachineMeta {
    string DID;
    uint256 amount;
    string proof;
    string settlement;
    string callForTenders;
    string[] tenderResponses;
    string tenderSelectionArgumentation;
    address owner;
    string reasonForRejection;
    string revisorComment;
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
    return STATE_DRAFT;
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

    if (state == STATE_DRAFT || state == STATE_NEEDS_UPDATE) {
      states = new bytes32[](2);
      states[0] = STATE_SUBMITTED;
      states[1] = STATE_SUBMITTED_WITH_EXCEPTION;
    }

    if (state == STATE_SUBMITTED || state == STATE_SUBMITTED_WITH_EXCEPTION) {
      states = new bytes32[](2);
      states[0] = STATE_REVIEWED;
      states[1] = STATE_NEEDS_UPDATE;
    }

    if (state == STATE_REVIEWED) {
      states = new bytes32[](4);
      states[0] = STATE_REJECTED;
      states[1] = STATE_APPROVED;
      states[2] = STATE_FORCE_APPROVED;
      states[3] = STATE_NEEDS_UPDATE;
    }

    if (state == STATE_APPROVED || state == STATE_FORCE_APPROVED) {
      states = new bytes32[](1);
      states[0] = STATE_REJECTED;
    }

    return states;
  }

  /**
   * @notice Retrieve all roles that are allowed to move it to the given state
   * @param state state
   */
  function getAllowedRolesForState(bytes32 state) public view override returns (bytes32[] memory) {
    bytes32[] memory roles;

    if (state == STATE_SUBMITTED || state == STATE_SUBMITTED_WITH_EXCEPTION) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_USER;
    }

    if (state == STATE_NEEDS_UPDATE) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_USER;
    }

    if (state == STATE_REVIEWED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_USER;
    }

    if (state == STATE_APPROVED || state == STATE_FORCE_APPROVED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_REVISOR;
    }

    if (state == STATE_REJECTED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_REVISOR;
    }

    return roles;
  }

  /**
   * @notice Returns method signatures for functions which are allowed to execute in the given state
   * @param state state
   */
  function getAllowedFunctionsForState(bytes32 state) public view override returns (bytes4[] memory) {
    bytes4[] memory functions;

    if (state == STATE_DRAFT) {
      functions = new bytes4[](4);
      functions[0] = this.addCallForTendersDocumentation.selector;
      functions[1] = this.addTenderResponse.selector;
      functions[2] = this.addTenderSelectionArgumentation.selector;
      functions[3] = this.edit.selector;
    }

    if (state == STATE_SUBMITTED || state == STATE_SUBMITTED_WITH_EXCEPTION) {
      functions = new bytes4[](2);
      functions[0] = this.setNeedsUpdateRejectionReason.selector;
      functions[1] = this.edit.selector;
    }

    if (state == STATE_REVIEWED) {
      functions = new bytes4[](2);
      functions[0] = this.setRejectedRejectionReason.selector;
      functions[1] = this.edit.selector;
    }

    if (state == STATE_APPROVED || state == STATE_FORCE_APPROVED) {
      functions = new bytes4[](2);
      functions[0] = this.setRejectedRejectionReason.selector;
      functions[1] = this.recordRevisorComment.selector;
    }

    return functions;
  }

  /**
   * @notice Returns method signatures for functions that act as preconditions that must be met in order to transition to the given state
   * @param state state
   */
  function getPreconditionsForState(bytes32 state) public view override returns (bytes4[] memory) {
    bytes4[] memory preConditions;

    if (
      state == STATE_SUBMITTED ||
      state == STATE_SUBMITTED_WITH_EXCEPTION ||
      state == STATE_NEEDS_UPDATE ||
      state == STATE_REJECTED
    ) {
      preConditions = new bytes4[](1);
      preConditions[0] = this.canBeSubmitted.selector;
    }

    return preConditions;
  }

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
   * @param amount expense amount
   * @param proof IPFS hash of the proof
   * @param settlement settlement method (Bank or Cash)
   * @param ipfsFieldContainerHash IPFS hash of the metadata fields
   * @param owner expense owner
   */
  function create(
    uint256 amount,
    string memory proof,
    string memory settlement,
    string memory ipfsFieldContainerHash,
    address owner
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    _registry.push();
    StateMachine storage sm = _registry[_registry.length - 1];
    sm.currentState = initialState();
    sm.createdAt = now;
    sm.index = _registry.length - 1;

    _meta.push();
    StateMachineMeta storage meta = _meta[_meta.length - 1];
    meta.amount = amount;
    meta.proof = proof;
    meta.settlement = settlement;
    meta.ipfsFieldContainerHash = ipfsFieldContainerHash;
    meta.owner = owner;
    meta.DID = generateDID(_meta.length - 1);

    _index.push();
    _index[_index.length - 1] = meta.DID;

    emit ExpenseCreated(sm.index, owner, _upgradeableRegistry);
  }

  /**
   * @notice Edit an existing statemachine
   * @param fsmIndex registry index of the statemachine struct
   * @param amount expense amount
   * @param proof IPFS hash of the proof
   * @param settlement settlement method (Bank or Cash)
   * @param callForTenders IPFS hash of the call for tenders document
   * @param ipfsFieldContainerHash IPFS hash of the metadata fields
   */
  function edit(
    uint256 fsmIndex,
    uint256 amount,
    string memory proof,
    string memory settlement,
    string memory callForTenders,
    string memory ipfsFieldContainerHash
  )
    public
    authManyWithCustomReason(_canEdit, 'Edit requires one of roles: ROLE_ADMIN, ROLE_CFP, ROLE_OB, ROLE_VDB')
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    // Verify input (copy paste of validations  we perform in the factory)
    require(amount > 0, 'The amount of an expense cannot be zero');
    require(bytes(proof).length > 0, 'A proof file is required for all expenses');

    // Verify input (trigger verifications that were done from REVIEWED -> SUBMITTED)
    canBeSubmitted(fsmIndex, _registry[fsmIndex].currentState, STATE_SUBMITTED);

    if (amount != _meta[fsmIndex].amount) {
      emit AmountChanged(msg.sender, _meta[fsmIndex].amount, amount);
    }

    if (uint256(keccak256(abi.encodePacked(proof))) != uint256(keccak256(abi.encodePacked(_meta[fsmIndex].proof)))) {
      emit ProofChanged(msg.sender, _meta[fsmIndex].proof, proof);
    }

    _meta[fsmIndex].amount = amount;
    _meta[fsmIndex].proof = proof;
    _meta[fsmIndex].settlement = settlement;
    _meta[fsmIndex].callForTenders = callForTenders;
    _meta[fsmIndex].ipfsFieldContainerHash = ipfsFieldContainerHash;

    transitionState(fsmIndex, STATE_REVIEWED);
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
  // Expense Functions
  //////

  /**
   * @notice Set rejection reason for STATE_NEEDS_UPDATE
   * @param fsmIndex state machine index
   * @param rejectionReason reason for rejection
   */
  function setNeedsUpdateRejectionReason(uint256 fsmIndex, string memory rejectionReason)
    public
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    setRejectionReason(fsmIndex, rejectionReason, STATE_NEEDS_UPDATE);
  }

  /**
   * @notice Set rejection reason for STATE_REJECTED
   * @param fsmIndex state machine index
   * @param rejectionReason reason for rejection
   */
  function setRejectedRejectionReason(uint256 fsmIndex, string memory rejectionReason)
    public
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    setRejectionReason(fsmIndex, rejectionReason, STATE_REJECTED);
  }

  /**
   * @notice Set a rejection reason document IPFS hash and transition to the given next state
   * @param fsmIndex state machine index
   * @param rejectionReason IPFS hash of the rejection reason document
   * @param nextState next state to transition to
   */
  function setRejectionReason(
    uint256 fsmIndex,
    string memory rejectionReason,
    bytes32 nextState
  ) private doesStateMachineExists(fsmIndex) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    bytes memory bytesRejectionReason = bytes(rejectionReason);
    require(bytesRejectionReason.length > 0, 'The rejection reason is required');
    meta.reasonForRejection = rejectionReason;
    transitionState(fsmIndex, nextState);
  }

  /**
   * @notice Add call for tenders IPFS hash
   * @param fsmIndex state machine index
   * @param callForTenders IPFS hash of the call for tenders document
   */
  function addCallForTendersDocumentation(uint256 fsmIndex, string memory callForTenders)
    public
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    bytes memory bytesCallForTenders = bytes(callForTenders);
    require(bytesCallForTenders.length > 0, 'You need to enter a call for tenders document');

    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.callForTenders = callForTenders;
  }

  /**
   * @notice Add tender response document IPFS hash
   * @param fsmIndex state machine index
   * @param tenderResponse IPFS hash of the tender response document
   */
  function addTenderResponse(uint256 fsmIndex, string memory tenderResponse)
    public
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    bytes memory bytesTenderResponse = bytes(tenderResponse);
    require(bytesTenderResponse.length > 0, 'You need to enter a call for tenders response document');

    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.tenderResponses.push(tenderResponse);
  }

  /**
   * @notice Add tender selection document IPFS hash
   * @param fsmIndex state machine index
   * @param tenderSelectionArgumentation IPFS hash of the tender selection document
   */
  function addTenderSelectionArgumentation(uint256 fsmIndex, string memory tenderSelectionArgumentation)
    public
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    bytes memory bytesTenderSelectionArgumentation = bytes(tenderSelectionArgumentation);
    require(bytesTenderSelectionArgumentation.length > 0, 'You need to enter a tender selection document');

    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.tenderSelectionArgumentation = tenderSelectionArgumentation;
  }

  /**
   * @notice Add revisor comment document IPFS hash
   * @param fsmIndex state machine index
   * @param revisorComment IPFS hash of the revisor comment document
   */
  function recordRevisorComment(uint256 fsmIndex, string memory revisorComment)
    public
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    bytes memory bytesRevisorComment = bytes(revisorComment);
    require(bytesRevisorComment.length > 0, 'You need to enter a revisor comment document');

    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.revisorComment = revisorComment;
  }

  /**
   * @notice Returns whether an expense can be submitted or not
   * @param fsmIndex state machine index
   * @param toState state where we are transitioning to
   * @dev This is a precondition function
   */
  function canBeSubmitted(
    uint256 fsmIndex,
    bytes32, /* fromState */
    bytes32 toState
  ) public view doesStateMachineExists(fsmIndex) {
    StateMachineMeta storage meta = _meta[fsmIndex];

    if (toState == STATE_SUBMITTED) {
      require(meta.amount > 0, 'The amount of an expense cannot be zero');
      if (meta.amount > 850000) {
        bytes memory callForTenders = bytes(meta.callForTenders);
        require(
          callForTenders.length > 0,
          'Since the amount of the expense is over 8500 euro, you need to upload a call for tenders'
        );
        bytes memory tenderSelectionArgumentation = bytes(meta.tenderSelectionArgumentation);
        require(
          tenderSelectionArgumentation.length > 0,
          'Since the amount of the expense is over 8500 euro, you need to upload the reasons for selecting a tender'
        );
        require(
          meta.tenderResponses.length >= 3,
          'Since the amount of the expense is over 8500 euro, you need to upload at least three tender responses'
        );
      }

      if (uint256(keccak256(abi.encodePacked(meta.settlement))) == uint256(keccak256(abi.encodePacked('Cash')))) {
        require(meta.amount <= 300000, 'Cash expenses need to be less or equal than 3000 euro ');
      }
    }
  }

  /**
   * @notice Returns whether an expense has a rejection reason set
   * @param fsmIndex state machine index
   * @dev This is a precondition function
   */
  function hasRejectionReason(
    uint256 fsmIndex,
    bytes32, /* fromState */
    bytes32 /*toState*/
  ) internal view doesStateMachineExists(fsmIndex) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    bytes memory reasonForRejection = bytes(meta.reasonForRejection);
    require(reasonForRejection.length > 0, 'A reason for a rejection is required');
  }

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
  {
    function(uint256, bytes32, bytes32) internal view[] memory preConditions;

    if (state == STATE_SUBMITTED || state == STATE_SUBMITTED_WITH_EXCEPTION) {
      preConditions = new function(uint256, bytes32, bytes32) internal view[](1);
      preConditions[0] = canBeSubmitted;
    }

    if (state == STATE_NEEDS_UPDATE || state == STATE_REJECTED) {
      preConditions = new function(uint256, bytes32, bytes32) internal view[](1);
      preConditions[0] = canBeSubmitted;
    }

    return preConditions;
  }

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
    return string(abi.encodePacked('did:vdb:expense:0x', addressToString(address(this)), ':', uintToString(fsmIndex)));
  }
}
