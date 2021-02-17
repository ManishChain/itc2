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

// Also Rework Roles
// Duration/Tenperature of an event omitted for simplicity
// IDEA: A Settings Struct with isMedical, Tilting temperature etc in?
// Get rid of this hideous code asap

pragma solidity ^0.6.3;
pragma experimental ABIEncoderV2;

import '@settlemint/enteth-contracts/contracts/provenance/statemachine/FiniteStateMachine.sol';
import '@settlemint/enteth-contracts/contracts/authentication/Secured.sol';
import '@settlemint/enteth-contracts/contracts/utility/ui/UIFieldDefinitions.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/IpfsFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/FileFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/utility/conversions/Converter.sol';

/**
 * @title Package Contract
 */
contract Package is FiniteStateMachine, IpfsFieldContainer, FileFieldContainer, UIFieldDefinitions {
  bytes32 public constant UPGRADEABLE_REGISTRY_TARGET = 'UPGRADEABLE_REGISTRY_TARGET';
  bytes32 public constant CREATE_STATEMACHINE_ROLE = 'CREATE_STATEMACHINE_ROLE';

  /**
   * Package Events
   */
  // Package Created event
  event StartLoadingEvent(uint256 fsmIndex, eventInfo info);
  event FinishLoadingEvent(uint256 fsmIndex, eventInfo info);
  event StartTransportationEvent(uint256 fsmIndex, eventInfo info); //StateSwitch
  event SentData(uint256 fsmIndex, eventInfo info);
  event StartChangedCarrier(uint256 fsmIndex, eventInfo info);
  event FinishChangedCarrier(uint256 fsmIndex, eventInfo info);
  event ArrivedToWareHouseEvent(uint256 fsmIndex, eventInfo info);
  event ArrivedToEndUserEvent(uint256 fsmIndex, eventInfo info);

  event PackageTiltingEvent(uint256 fsmIndex, eventInfo info);
  event CoolingMalfunctionEvent(uint256 fsmIndex, eventInfo info);

  //Duration todo
  event TrafficJamEvent(uint256 fsmIndex, eventInfo info);
  event ItMalfunctionEvent(uint256 fsmIndex, eventInfo info);

  event CheckSmartContractEvent(uint256 fsmIndex, eventInfo info, packageIssue[] issues); //, packageIssue[] issues);

  /**
   * State Constants -> Possible DelayState?
   *
   * STATE_PACKAGE_LOADED = the Package is added, possibly with missing info
   * STATE_PACKAGE_IN_TRANSIT =
   * STATE_ARRIVED_TO_WAREHOUS =
   * STATE_PACKAGE_CHANGED_CAR =
   * STATE_ARRIVED_TO_END_USER =
   */

  //Change State names
  bytes32 private constant STATE_PACKAGE_LOADED = 'PACKAGE_LOADED';
  bytes32 private constant STATE_PACKAGE_IN_TRANSIT = 'PACKAGE_IN_TRANSIT';
  bytes32 private constant STATE_ARRIVED_TO_WAREHOUSE = 'ARRIVED_TO_WAREHOUSE';
  bytes32 private constant STATE_PACKAGE_CHANGED_CARRIER = 'PACKAGE_CHANGED_CARRIER';
  bytes32 private constant STATE_ARRIVED_TO_END_USER = 'ARRIVED_TO_END_USER';

  /*
   * Role Constants
   */
  bytes32 private constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 private constant ROLE_USER = 'ROLE_USER';

  /**
   * Package states
   */
  bytes32[] public _allStates = [
    STATE_PACKAGE_LOADED,
    STATE_PACKAGE_IN_TRANSIT,
    STATE_ARRIVED_TO_WAREHOUSE,
    STATE_PACKAGE_CHANGED_CARRIER,
    STATE_ARRIVED_TO_END_USER
  ];

  /**
   * Package roles
   */
  bytes32[] public _allRoles = [ROLE_ADMIN, ROLE_USER];

  /**
   * Package helper role collection
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
   * Package Specific types
   *
   *
   *
   */

  enum IssueType { trafficJam, coolingMalfunction, tilting, itMalfunction }
  // => casing in enums google
  struct packageIssue {
    IssueType issue;
    uint256 timestamp;
  }

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
   * @dev Struct defining an Package
   * @notice Gets decorated together with the StateMachine structs and forms the Package FSM
   */
  struct StateMachineMeta {
    string DID;
    string name;
    string comment;
    bool isMedical;
    bool tiltable;
    bool temperatureIgnored; //Smaller type maybe? //skip fn
    uint256 temperatureThreshold; //currently string ???
    packageIssue[] issues;
    string currentCarrier;
    uint256 start;
    uint256 temperature;
    string[] gpsLocations; // lat, long
    address owner;
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
    return STATE_PACKAGE_LOADED;
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

    if (state == STATE_PACKAGE_LOADED) {
      states = new bytes32[](1);
      states[0] = STATE_PACKAGE_IN_TRANSIT;
    }

    if (state == STATE_PACKAGE_IN_TRANSIT) {
      states = new bytes32[](2);
      states[0] = STATE_ARRIVED_TO_WAREHOUSE;
      states[1] = STATE_ARRIVED_TO_END_USER;
    }

    if (state == STATE_ARRIVED_TO_WAREHOUSE) {
      states = new bytes32[](1);
      states[0] = STATE_PACKAGE_CHANGED_CARRIER;
    }

    if (state == STATE_PACKAGE_CHANGED_CARRIER) {
      states = new bytes32[](1);
      states[0] = STATE_PACKAGE_IN_TRANSIT;
    }

    return states;
  }

  /**
   * @notice Retrieve all roles that are allowed to move it to the given state
   * @param state state
   * TODO: Roles
   */
  function getAllowedRolesForState(bytes32 state) public view override returns (bytes32[] memory) {
    bytes32[] memory roles;

    if (state == STATE_PACKAGE_LOADED) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_USER;
    }

    if (state == STATE_PACKAGE_IN_TRANSIT) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_USER;
    }

    if (state == STATE_ARRIVED_TO_WAREHOUSE) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_USER;
    }

    if (state == STATE_PACKAGE_CHANGED_CARRIER) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_USER;
    }

    if (state == STATE_ARRIVED_TO_END_USER) {
      roles = new bytes32[](2);
      roles[0] = ROLE_ADMIN;
      roles[1] = ROLE_USER;
    }

    return roles;
  }

  /**
   * @notice Returns method signatures for functions which are allowed to execute in the given state
   * @param state state
   */
  function getAllowedFunctionsForState(bytes32 state) public view override returns (bytes4[] memory) {
    bytes4[] memory functions;

    if (state == STATE_PACKAGE_LOADED) {
      functions = new bytes4[](3);
      functions[0] = this.startLoadingTruck.selector;
      functions[1] = this.finishLoadingTruck.selector;
      functions[2] = this.edit.selector; //edit function only here?
    }

    if (state == STATE_PACKAGE_IN_TRANSIT) {
      functions = new bytes4[](6);
      functions[0] = this.setPackageTilting.selector;
      functions[1] = this.setCoolingMalfunction.selector;
      functions[2] = this.setTrafficJam.selector;
      functions[3] = this.sendData.selector;
      functions[4] = this.arrivedToWarehouse.selector;
      functions[5] = this.arrivedToEndUser.selector;
    }

    if (state == STATE_ARRIVED_TO_WAREHOUSE) {
      functions = new bytes4[](2);
      functions[0] = this.startChangeCarrier.selector;
      functions[1] = this.setItMalfunction.selector;
    }

    if (state == STATE_PACKAGE_CHANGED_CARRIER) {
      functions = new bytes4[](2);
      functions[0] = this.finishChangeCarrier.selector;
      functions[1] = this.setItMalfunction.selector;
    }

    if (state == STATE_ARRIVED_TO_END_USER) {
      functions = new bytes4[](1);
      functions[0] = this.checkSmartContract.selector;
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
  // Factory Functions => Rework wit hupdated stm
  //////

  /**
   * @notice Create a new statemachine
   * @param name Package type
   * @param comment is the package tiltable
   * @param isMedical is the package medical
   * @param temperatureIgnored is the temp ignores
   * @param temperatureThreshold tresh
   * @param ipfsFieldContainerHash IPFS hash df the metadata fields
   * @param owner Package owner
   */
  function create(
    string memory name,
    string memory comment,
    bool isMedical,
    bool tiltable,
    bool temperatureIgnored,
    uint256 temperatureThreshold,
    string memory ipfsFieldContainerHash,
    address owner
  ) public authWithCustomReason(CREATE_STATEMACHINE_ROLE, 'Sender needs CREATE_STATEMACHINE_ROLE') {
    _registry.push();
    StateMachine storage sm = _registry[_registry.length - 1];
    sm.currentState = initialState();
    sm.createdAt = now;
    sm.index = _registry.length - 1;
    //This registry later?

    _meta.push();
    StateMachineMeta storage meta = _meta[_meta.length - 1];
    meta.name = name;
    meta.comment = comment;
    meta.isMedical = isMedical;
    meta.tiltable = tiltable;
    meta.temperatureIgnored = temperatureIgnored;
    meta.temperatureThreshold = temperatureThreshold;
    meta.currentCarrier = 'Carrier One';
    meta.ipfsFieldContainerHash = ipfsFieldContainerHash;
    meta.owner = owner;
    meta.DID = generateDID(_meta.length - 1);

    _index.push();
    _index[_index.length - 1] = meta.DID;

    //emit PackageCreated(sm.index, owner, _upgradeableRegistry); //Event maken
  }

  /**
   * @notice Edit an existing statemachine
   * @param name Package type
   * @param comment is the package tiltable
   * @param isMedical is the package tiltable
   * @param temperatureIgnored is the temp ignores
   * @param temperatureThreshold tresh
   * @param ipfsFieldContainerHash IPFS hash df the metadata fields
   */
  function edit(
    uint256 fsmIndex,
    string memory name,
    string memory comment,
    bool isMedical,
    bool tiltable,
    bool temperatureIgnored,
    uint256 temperatureThreshold,
    string memory ipfsFieldContainerHash
  )
    public
    //authManyWithCustomReason(_canEdit, 'Edit requires one of roles: ROLE_ADMIN')
    doesStateMachineExists(fsmIndex)
    checkAllowedFunction(_registry[fsmIndex].currentState)
  {
    // Verify input (copy paste of validations  we perform in the factory)
    //require(amount > 0, 'The amount of an Package cannot be zero');
    // require(bytes(packageName).length > 0, 'A packageName is required for all Packages');

    _meta[fsmIndex].name = name;
    _meta[fsmIndex].comment = comment;
    _meta[fsmIndex].isMedical = isMedical; //Enum Maybe toch niet
    _meta[fsmIndex].tiltable = tiltable;
    _meta[fsmIndex].temperatureIgnored = temperatureIgnored;
    _meta[fsmIndex].temperatureThreshold = temperatureThreshold;
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
  // Package Functions
  //////

  struct eventInfo {
    string name;
    string carrier;
    uint256 time;
    string lat;
    string long;
    uint256 temp;
  }

  /**
   * @notice StartLoading Truck
   * @param fsmIndex state machine index
   */
  function startLoadingTruck(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.start = time;
    meta.gpsLocations = new string[](2);
    meta.gpsLocations[0] = lat;
    meta.gpsLocations[1] = long;
    eventInfo memory info = eventInfo({
      name: 'START LOADING',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit StartLoadingEvent(fsmIndex, info); //carrier?
  }

  //Which functions does Package need?
  /**
   * @notice finish Loading Truck
   * @param fsmIndex state machine index
   * @param time start time of the loading
   *
   */
  function finishLoadingTruck(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.gpsLocations = new string[](2);
    meta.gpsLocations[0] = lat;
    meta.gpsLocations[1] = long;
    eventInfo memory info = eventInfo({
      name: 'FINISH LOADING',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit FinishLoadingEvent(fsmIndex, info); //carrier?
    transitionState(fsmIndex, STATE_PACKAGE_IN_TRANSIT);
  }

  /**
   * @notice setPackageTilting
   * @param fsmIndex state machine index
   * @param time start time of the loading
   *
   */

  function setPackageTilting(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.gpsLocations = new string[](2);
    meta.gpsLocations[0] = lat;
    meta.gpsLocations[1] = long;
    meta.issues.push(packageIssue({ issue: IssueType.tilting, timestamp: time }));
    eventInfo memory info = eventInfo({
      name: 'PACKAGE TILTING',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });

    emit PackageTiltingEvent(fsmIndex, info);
  }

  /**
   * @notice setCoolingMalfunction
   * @param fsmIndex state machine index
   * @param time start time of the loading
   *
   */

  function setCoolingMalfunction(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long,
    uint256 temp
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.gpsLocations = new string[](2);
    meta.gpsLocations[0] = lat;
    meta.gpsLocations[1] = long;
    meta.issues.push(packageIssue({ issue: IssueType.coolingMalfunction, timestamp: time }));
    meta.temperature = temp;
    eventInfo memory info = eventInfo({
      name: 'COOLING MALFUNCTION',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: temp
    });
    emit CoolingMalfunctionEvent(fsmIndex, info);
  }

  /**
   * @notice itMalfunction function
   * @param fsmIndex state machine index
   * @param time start time of the loading
   *
   */

  function setItMalfunction(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.gpsLocations = new string[](2);
    meta.gpsLocations[0] = lat;
    meta.gpsLocations[1] = long;
    meta.issues.push(packageIssue({ issue: IssueType.itMalfunction, timestamp: time }));
    eventInfo memory info = eventInfo({
      name: 'IT MALFUNCTION',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit ItMalfunctionEvent(fsmIndex, info);
  }

  /**
   * @notice finish Loading Truck event
   * @param fsmIndex state machine index
   */

  function setTrafficJam(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.gpsLocations = new string[](2);
    meta.gpsLocations[0] = lat;
    meta.gpsLocations[1] = long;
    meta.issues.push(packageIssue({ issue: IssueType.trafficJam, timestamp: time }));
    eventInfo memory info = eventInfo({
      name: 'TRAFFIC JAM',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit TrafficJamEvent(fsmIndex, info);
  }

  /**
   * @notice finish Loading Truck event
   * @param fsmIndex state machine index
   * @param time time
   *
   */

  function sendData(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long,
    uint256 temp
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.gpsLocations = new string[](2);
    meta.gpsLocations[0] = lat;
    meta.gpsLocations[1] = long;
    meta.temperature = temp;
    eventInfo memory info = eventInfo({
      name: 'SENT DATA',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: temp
    });
    emit SentData(fsmIndex, info);
  }

  /**
   * @notice finish Loading Truck event
   * @param fsmIndex state machine index
   * @param time time
   */

  function arrivedToWarehouse(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.gpsLocations = new string[](2);
    meta.gpsLocations[0] = lat;
    meta.gpsLocations[1] = long;
    eventInfo memory info = eventInfo({
      name: 'ARRIVED TO WAREHOUSE',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit ArrivedToWareHouseEvent(fsmIndex, info);
    transitionState(fsmIndex, STATE_ARRIVED_TO_WAREHOUSE);
  }

  /**
   * @notice finish Loading Truck event
   * @param fsmIndex state machine index
   * @param time time
   *
   */

  function arrivedToEndUser(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    eventInfo memory info = eventInfo({
      name: 'ARRIVED TO ENDUSER',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit ArrivedToEndUserEvent(fsmIndex, info);
    transitionState(fsmIndex, STATE_ARRIVED_TO_END_USER);
  }

  /**
   * @notice finish Loading Truck event
   * @param fsmIndex state machine index
   * @param time time
   *
   */

  function startChangeCarrier(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long,
    string memory newCarrier
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    meta.currentCarrier = newCarrier;
    eventInfo memory info = eventInfo({
      name: 'START CHANGE CARRIER',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit StartChangedCarrier(fsmIndex, info); // new Carrier
    transitionState(fsmIndex, STATE_PACKAGE_CHANGED_CARRIER);
  }

  /**
   * @notice finishChangeCarrier
   * @param fsmIndex state machine index
   * @param time time
   *
   */
  function finishChangeCarrier(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    eventInfo memory info = eventInfo({
      name: 'FINISH CHANGE CARRIER',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit FinishChangedCarrier(fsmIndex, info);
    transitionState(fsmIndex, STATE_PACKAGE_IN_TRANSIT);
  }

  /**
   * @notice checkSmartContract
   * @param fsmIndex state machine index
   * @param time time
   *
   */
  function checkSmartContract(
    uint256 fsmIndex,
    uint256 time,
    string memory lat,
    string memory long
  ) public doesStateMachineExists(fsmIndex) checkAllowedFunction(_registry[fsmIndex].currentState) {
    StateMachineMeta storage meta = _meta[fsmIndex];
    //issues??
    eventInfo memory info = eventInfo({
      name: 'CHECK SMARTCONTRACT',
      carrier: meta.currentCarrier,
      time: time,
      lat: lat,
      long: long,
      temp: meta.temperature
    });
    emit CheckSmartContractEvent(fsmIndex, info, meta.issues); //order them right?
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
    return string(abi.encodePacked('did:demo:package:0x', addressToString(address(this)), ':', uintToString(fsmIndex)));
  }
}
