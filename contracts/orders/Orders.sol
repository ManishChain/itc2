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
contract Orders is FiniteStateMachine, IpfsFieldContainer, FileFieldContainer, UIFieldDefinitions {
  bytes32 public constant CREATE_STATEMACHINE_ROLE = 'CREATE_STATEMACHINE_ROLE';

  /**
   * SupplierContract Events
   */
  event OrderCreated(uint256 fsmIndex, address owner, address registry);
  // event BillOfLadingSubmitted(address owner, address expense, uint256 amount);
  // event BillOfLadingSubmittedWithException(address owner, address expense, uint256 amount, string comment);
  // event BillOfLadingReviewed(address owner, address expense, uint256 amount);
  // event BillOfLadingNeedsUpdate(address owner, address expense, uint256 amount, string comment);
  // event BillOfLadingAccepted(address owner, address expense, uint256 amount);
  // event BillOfLadingRejected(address owner, address expense, uint256 amount, string comment);
  // event BillOfLadingForceApproved(address owner, address expense, uint256 amount, string comment);
  // event AmountChanged(address sender, uint256 fromAmount, uint256 toAmount);
  // event ProofChanged(address sender, string fromProof, string toProof);

  /**
   * State Constants
   */
  bytes32 private constant STATE_ORDER_PLACED = 'ORDER_PLACED';
  bytes32 private constant STATE_ORDER_ACCEPTED = 'ORDER_ACCEPTED';
  bytes32 private constant STATE_ORDER_DENIED = 'ORDER_DENIED';
  bytes32 private constant STATE_ORDER_SHIPPED = 'ORDER_SHIPPED';
  bytes32 private constant STATE_SHIPMENT_RECEIVED = 'SHIPMENT_RECEIVED';
  bytes32 private constant STATE_SHIPMENT_ACCEPTED = 'SHIPMENT_ACCEPTED';
  bytes32 private constant STATE_SHIPMENT_DENIED = 'SHIPMENT_DENIED';
  bytes32 private constant STATE_BILL_SENT = 'BILL_SENT';
  bytes32 private constant STATE_BILL_RECEIVED = 'BILL_RECEIVED';
  bytes32 private constant STATE_BILL_ACCEPTED = 'BILL_ACCEPTED';
  bytes32 private constant STATE_BILL_DENIED = 'BILL_DENIED';
  bytes32 private constant STATE_BILLED_TO_BUSINESS_UNIT = 'BILLED_TO_BUSINESS_UNIT';
  bytes32 private constant STATE_PAYMENT_ISSUED = 'PAYMENT_ISSUED';
  bytes32 private constant STATE_PAYMENT_RECEIVED = 'STATE_PAYMENT_RECEIVED';

  /**
   * Role Constants
   */
  bytes32 private constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 private constant ROLE_SUPPLIER = 'ROLE_SUPPLIER';
  bytes32 private constant ROLE_SSC = 'ROLE_SSC';
  bytes32 private constant ROLE_BU = 'ROLE_BU';

  /**
   * BillOfLading states
   */
  bytes32[] public _allStates = [
    STATE_ORDER_PLACED,
    STATE_ORDER_ACCEPTED,
    STATE_ORDER_DENIED,
    STATE_ORDER_SHIPPED,
    STATE_SHIPMENT_RECEIVED,
    STATE_SHIPMENT_ACCEPTED,
    STATE_SHIPMENT_DENIED,
    STATE_BILL_SENT,
    STATE_BILL_RECEIVED,
    STATE_BILL_ACCEPTED,
    STATE_BILL_DENIED,
    STATE_BILLED_TO_BUSINESS_UNIT,
    STATE_PAYMENT_ISSUED,
    STATE_PAYMENT_RECEIVED
  ];

  /**
   * BillOfLading roles
   */
  bytes32[] public _allRoles = [ROLE_ADMIN, ROLE_SUPPLIER, ROLE_SSC, ROLE_BU];

  /**
   * BillOfLading helper role collection
   * specifies anyone who can edit an exponse
   */
  bytes32[] private _canEdit = [ROLE_ADMIN, ROLE_SSC];

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
    address businessUnit;
    uint256 InBoneChickenPerKg;
    uint256 InBoneChickenTotal;
    uint256 WokForTwoPerPackage;
    uint256 WokForTwoTotal;
    uint256 FreeRangeChickenPerChicken;
    uint256 FreeRangeChickenTotal;
    uint256 PastaSaladPerPackage;
    uint256 PastaSaladTotal;
    uint256 orderTotal;
    string ipfsFieldContainerHash;
  }

  mapping(string => uint256) public prices;

  constructor(address gateKeeper, address registry) public Secured(gateKeeper) {
    require(registry != address(0x0), 'registry can not be zero');
    _upgradeableRegistry = registry;

    prices['InBoneChickenPerKg'] = 199;
    prices['WokForTwoPerPackage'] = 349;
    prices['FreeRangeChickenPerChicken'] = 499;
    prices['PastaSaladPerPackage'] = 299;
  }

  //////
  // FSM Definition Functions
  //////

  /**
   * @notice Returns initial state
   */
  function initialState() public pure override returns (bytes32) {
    return STATE_ORDER_PLACED;
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

    if (state == STATE_ORDER_PLACED) {
      states = new bytes32[](2);
      states[0] = STATE_ORDER_ACCEPTED;
      states[1] = STATE_ORDER_DENIED;
    }
    if (state == STATE_ORDER_ACCEPTED) {
      states = new bytes32[](1);
      states[0] = STATE_ORDER_SHIPPED;
    }
    if (state == STATE_ORDER_SHIPPED) {
      states = new bytes32[](1);
      states[0] = STATE_SHIPMENT_RECEIVED;
    }
    if (state == STATE_SHIPMENT_RECEIVED) {
      states = new bytes32[](2);
      states[0] = STATE_SHIPMENT_ACCEPTED;
      states[1] = STATE_SHIPMENT_DENIED;
    }
    if (state == STATE_SHIPMENT_ACCEPTED) {
      states = new bytes32[](1);
      states[0] = STATE_BILL_SENT;
    }
    if (state == STATE_BILL_SENT) {
      states = new bytes32[](1);
      states[0] = STATE_BILL_RECEIVED;
    }
    if (state == STATE_BILL_RECEIVED) {
      states = new bytes32[](2);
      states[0] = STATE_BILL_ACCEPTED;
      states[1] = STATE_BILL_DENIED;
    }
    if (state == STATE_BILL_ACCEPTED) {
      states = new bytes32[](1);
      states[0] = STATE_BILLED_TO_BUSINESS_UNIT;
    }
    if (state == STATE_BILLED_TO_BUSINESS_UNIT) {
      states = new bytes32[](1);
      states[0] = STATE_PAYMENT_ISSUED;
    }
    if (state == STATE_PAYMENT_ISSUED) {
      states = new bytes32[](1);
      states[0] = STATE_PAYMENT_RECEIVED;
    }

    return states;
  }

  /**
   * @notice Retrieve all roles that are allowed to move it to the given state
   * @param state state
   */
  function getAllowedRolesForState(bytes32 state) public view override returns (bytes32[] memory) {
    bytes32[] memory roles;

    if (state == STATE_ORDER_PLACED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_BU;
    }
    if (state == STATE_ORDER_ACCEPTED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SUPPLIER;
    }
    if (state == STATE_ORDER_DENIED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SUPPLIER;
    }
    if (state == STATE_ORDER_SHIPPED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SUPPLIER;
    }
    if (state == STATE_SHIPMENT_RECEIVED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_BU;
    }
    if (state == STATE_SHIPMENT_ACCEPTED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_BU;
    }
    if (state == STATE_SHIPMENT_DENIED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_BU;
    }
    if (state == STATE_BILL_SENT) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SUPPLIER;
    }
    if (state == STATE_BILL_RECEIVED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SSC;
    }
    if (state == STATE_BILL_ACCEPTED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SSC;
    }
    if (state == STATE_BILL_DENIED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SSC;
    }
    if (state == STATE_BILLED_TO_BUSINESS_UNIT) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SSC;
    }
    if (state == STATE_PAYMENT_ISSUED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SSC;
    }
    if (state == STATE_PAYMENT_RECEIVED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_SUPPLIER;
    }

    return roles;
  }

  /**
   * @notice Returns method signatures for functions which are allowed to execute in the given state
   * @param state state
   */
  function getAllowedFunctionsForState(bytes32 state) public view override returns (bytes4[] memory) {}

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
  // Factory Functions
  //////

  /**
   * @notice Create a new statemachine
   * @param ipfsFieldContainerHash IPFS hash of the metadata fields
   */
  function create(
    address businessUnit,
    uint256 InBoneChickenPerKg,
    uint256 WokForTwoPerPackage,
    uint256 FreeRangeChickenPerChicken,
    uint256 PastaSaladPerPackage,
    string memory ipfsFieldContainerHash
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    _registry.push();
    StateMachine storage sm = _registry[_registry.length - 1];
    sm.currentState = initialState();
    sm.createdAt = now;
    sm.index = _registry.length - 1;

    _meta.push();
    StateMachineMeta storage meta = _meta[_meta.length - 1];
    meta.businessUnit = businessUnit;
    meta.ipfsFieldContainerHash = ipfsFieldContainerHash;
    meta.InBoneChickenPerKg = InBoneChickenPerKg;
    meta.InBoneChickenTotal = InBoneChickenPerKg * prices['InBoneChickenPerKg'];
    meta.WokForTwoPerPackage = WokForTwoPerPackage;
    meta.WokForTwoTotal = WokForTwoPerPackage * prices['WokForTwoPerPackage'];
    meta.FreeRangeChickenPerChicken = FreeRangeChickenPerChicken;
    meta.FreeRangeChickenTotal = FreeRangeChickenPerChicken * prices['FreeRangeChickenPerChicken'];
    meta.PastaSaladPerPackage = PastaSaladPerPackage;
    meta.PastaSaladTotal = PastaSaladPerPackage * prices['PastaSaladPerPackage'];
    meta.DID = generateDID(_meta.length - 1);
    meta.orderTotal = meta.InBoneChickenTotal + meta.WokForTwoTotal + meta.FreeRangeChickenTotal + meta.PastaSaladTotal;

    _index.push();
    _index[_index.length - 1] = meta.DID;

    emit OrderCreated(sm.index, msg.sender, _upgradeableRegistry);
  }

  /**
   * @notice Edit an existing statemachine
   * @param fsmIndex registry index of the statemachine struct
   * @param ipfsFieldContainerHash IPFS hash of the metadata fields
   */
  function edit(
    uint256 fsmIndex,
    address businessUnit,
    uint256 InBoneChickenPerKg,
    uint256 WokForTwoPerPackage,
    uint256 FreeRangeChickenPerChicken,
    uint256 PastaSaladPerPackage,
    string memory ipfsFieldContainerHash
  )
    public
    authManyWithCustomReason(_canEdit, 'Edit requires one of roles: ROLE_ADMIN')
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.businessUnit = businessUnit;
    meta.ipfsFieldContainerHash = ipfsFieldContainerHash;
    meta.businessUnit = businessUnit;
    meta.ipfsFieldContainerHash = ipfsFieldContainerHash;
    meta.InBoneChickenPerKg = InBoneChickenPerKg;
    meta.InBoneChickenTotal = InBoneChickenPerKg * prices['InBoneChickenPerKg'];
    meta.WokForTwoPerPackage = WokForTwoPerPackage;
    meta.WokForTwoTotal = WokForTwoPerPackage * prices['WokForTwoPerPackage'];
    meta.FreeRangeChickenPerChicken = FreeRangeChickenPerChicken;
    meta.FreeRangeChickenTotal = FreeRangeChickenPerChicken * prices['FreeRangeChickenPerChicken'];
    meta.PastaSaladPerPackage = PastaSaladPerPackage;
    meta.PastaSaladTotal = PastaSaladPerPackage * prices['PastaSaladPerPackage'];
    meta.orderTotal = meta.InBoneChickenTotal + meta.WokForTwoTotal + meta.FreeRangeChickenTotal + meta.PastaSaladTotal;
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
  // Helper Functions
  //////

  /**
   * @notice Generate state machine DID
   * @param fsmIndex state machine index
   */
  function generateDID(uint256 fsmIndex) internal view returns (string memory) {
    return string(abi.encodePacked('did:order:orders:0x', addressToString(address(this)), ':', uintToString(fsmIndex)));
  }
}
