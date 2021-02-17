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

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import './StatefulOmnibusBond.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/FileFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/authentication/Secured.sol';
import '@settlemint/enteth-contracts/contracts/utility/syncing/Syncable.sol';
import '@settlemint/enteth-contracts/contracts/tokens/IWithDecimalFields.sol';

contract BondManager is Secured, Syncable, FileFieldContainer, IWithDecimalFields {
  bytes32 private constant REQUEST_STATUS_PENDING = 'PENDING';
  bytes32 private constant REQUEST_STATUS_APPROVED = 'APPROVED';
  bytes32 private constant REQUEST_STATUS_DENIED = 'DENIED';
  bytes32 private constant REQUEST_STATUS_CREATED_INFLIGHT = 'CREATED_INFLIGHT';
  bytes32 private constant REQUEST_STATUS_COMPLETED = 'COMPLETED';
  bytes32 private constant REQUEST_STATUS_COMPLETED_NOT_SETTLED = 'COMPLETED_NOT_SETTLED';
  bytes32 private constant REQUEST_STATUS_CANCELED_NOT_SETTLED = 'CANCELED_NOT_SETTLED';

  bytes32 private constant MINT = 'MINT';
  bytes32 private constant BURN = 'BURN';

  bytes32 private constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 private constant ROLE_MAKER = 'ROLE_MAKER';
  bytes32 private constant ROLE_CHECKER = 'ROLE_CHECKER';

  string internal accountWM = 'WealthManagement';

  bytes32[] private _canRequest = [ROLE_ADMIN, ROLE_MAKER];
  bytes32[] private _canApproveOrDeny = [ROLE_ADMIN, ROLE_CHECKER];
  bytes32[] private _canSettle = [ROLE_ADMIN, ROLE_CHECKER];

  bytes32[] private _roles = [ROLE_ADMIN, ROLE_MAKER, ROLE_CHECKER];

  function getRoles() public view returns (bytes32[] memory) {
    return _roles;
  }

  StatefulOmnibusBond internal _statefulOmnibusBond;
  string public _nameBond;
  string public _uiFieldDefinitionsHash;

  struct Request {
    bytes32 requestType;
    bytes32 status;
    uint256 index;
    uint256 amount;
    uint256 price;
    uint256 timeStamp;
    string account;
    string reason;
    string comment;
    string settlingComment;
    bytes32 inflight;
  }

  Request[] public requests;
  uint256 internal _requestsLength;

  constructor(
    GateKeeper gateKeeper,
    address statefulOmnibusBondAddress,
    string memory nameBond,
    string memory uiFieldDefinitionsHash
  ) public Secured(address(gateKeeper)) {
    _statefulOmnibusBond = StatefulOmnibusBond(statefulOmnibusBondAddress);
    _nameBond = nameBond;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
  }

  function createMintRequest(
    uint256 amount,
    uint256 price,
    bytes32 inflight,
    string memory comment
  ) public authManyWithCustomReason(_canRequest, 'Creating a request requires an admin or maker role') {
    require(_statefulOmnibusBond.isInActiveState(), 'The bond must be in active state');
    _requestsLength++;
    Request storage r = requests.push();
    r.index = _requestsLength - 1;
    r.requestType = MINT;
    r.status = REQUEST_STATUS_PENDING;
    r.amount = amount;
    r.price = price;
    r.account = accountWM;
    r.reason = comment;
    r.inflight = inflight;
  }

  function getDecimalsFor(bytes memory fieldName) public view override returns (uint256) {
    uint256 decVal = _statefulOmnibusBond.getDecimalsFor(fieldName);
    return decVal;
  }

  function createBurnRequest(
    uint256 amount,
    uint256 price,
    string memory account,
    string memory comment
  ) public authManyWithCustomReason(_canRequest, 'Creating a request requires an admin or maker role') {
    require(_statefulOmnibusBond.isInActiveState(), 'The bond must be in active state');
    _requestsLength++;
    Request storage r = requests.push();
    r.index = _requestsLength - 1;
    r.requestType = BURN;
    r.status = REQUEST_STATUS_PENDING;
    r.amount = amount;
    r.price = price;
    r.account = account;
    r.reason = comment;
    r.inflight = 'NO';
  }

  function approveRequest(uint256 index, string memory comment)
    public
    authManyWithCustomReason(_canApproveOrDeny, 'Approving/Denying requires an admin or checker role')
  {
    require(_statefulOmnibusBond.isInActiveState(), 'The bond must be in active state');
    require(index < _requestsLength, 'Index out of range');
    Request storage r = requests[index];
    require(r.status == REQUEST_STATUS_PENDING, 'The request should be pending');
    r.comment = comment;
    r.status = REQUEST_STATUS_APPROVED;
    r.timeStamp = now;

    executeRequest(index);
  }

  function denyRequest(uint256 index, string memory comment)
    public
    authManyWithCustomReason(_canApproveOrDeny, 'Approving/Denying requires an admin or checker role')
  {
    require(_statefulOmnibusBond.isInActiveState(), 'The bond must be in active state');
    require(index < _requestsLength, 'Index out of range');
    Request storage r = requests[index];
    require(r.status == REQUEST_STATUS_PENDING, 'The request should be pending');
    r.comment = comment;
    r.status = REQUEST_STATUS_DENIED;
    r.timeStamp = now;
  }

  function executeRequest(uint256 index) private {
    require(_statefulOmnibusBond.isInActiveState(), 'The bond must be in active state');
    require(index < _requestsLength, 'Index out of range');
    Request storage r = requests[index];
    require(r.status == REQUEST_STATUS_APPROVED, 'The request is not in approved state');
    if (r.requestType == BURN) {
      _statefulOmnibusBond.burn(r.account, r.amount, r.price);
      r.status = REQUEST_STATUS_COMPLETED;
    } else if (r.requestType == MINT) {
      if (r.inflight == 'YES') {
        _statefulOmnibusBond.mintInflight(r.account, r.amount, r.price);
        r.status = REQUEST_STATUS_CREATED_INFLIGHT;
      } else {
        _statefulOmnibusBond.mint(r.account, r.amount, r.price);
        r.status = REQUEST_STATUS_COMPLETED;
      }
    }
  }

  function settled(uint256 index, string memory comment)
    public
    authManyWithCustomReason(_canSettle, 'needs required role to settle/unsettle inflight bonds')
  {
    require(index < _requestsLength, 'Index out of range');
    Request storage r = requests[index];
    require(r.status == REQUEST_STATUS_CREATED_INFLIGHT, 'the request for bonds must be in CREATED_INFLIGHT status');
    require(r.inflight == 'YES', 'the bonds should be inflight');

    _statefulOmnibusBond.convertInflight(r.amount);

    r.inflight = 'NO';
    r.status = REQUEST_STATUS_COMPLETED;
    r.settlingComment = comment;
  }

  function notSettled(uint256 index, string memory comment)
    public
    authManyWithCustomReason(_canSettle, 'needs required role to settle/unsettle inflight bonds')
  {
    require(index < _requestsLength, 'Index out of range');
    Request storage r = requests[index];
    require(
      r.status == REQUEST_STATUS_CREATED_INFLIGHT || r.status == REQUEST_STATUS_PENDING,
      'the request for bonds must be in CREATED_INFLIGHT or PENDING status'
    );
    require(r.inflight == 'YES', 'the bonds should be inflight');

    if (r.status == REQUEST_STATUS_PENDING) {
      r.status = REQUEST_STATUS_CANCELED_NOT_SETTLED;
    } else {
      _statefulOmnibusBond.burnInflight(r.amount);
      r.status = REQUEST_STATUS_COMPLETED_NOT_SETTLED;
    }

    r.settlingComment = comment;
  }

  /**
   * @notice Returns the amount of requests.
   * @dev Gets the amount of requests, used by the middleware to build a cache you can query.
   *      You should not need this function in general since iteration this way clientside is very slow.
   *
   * @return length An uint256 representing the amount of requests recorded in this contract.
   */
  function getIndexLength() public view override returns (uint256 length) {
    length = requests.length;
  }

  /**
   * @notice Returns the request by index
   * @dev Gets request, used by the middleware to build a cache you can query.
   *      You should not need this function in general since iteration this way clientside is very slow.
   *
   * @param index       used to access the requests array
   */
  function getByIndex(uint256 index)
    public
    view
    returns (
      bytes32 status,
      bytes32 requestType,
      uint256 indexRow,
      uint256 amount,
      uint256 price,
      bytes32 inflight,
      string memory account,
      string memory reason,
      string memory comment,
      string memory settlingComment
    )
  {
    require(index < requests.length, 'Index out of range');
    status = requests[index].status;
    requestType = requests[index].requestType;
    indexRow = index;
    amount = requests[index].amount;
    account = requests[index].account;
    reason = requests[index].reason;
    comment = requests[index].comment;
    settlingComment = requests[index].settlingComment;
    price = requests[index].price;
    inflight = requests[index].inflight;
  }

  function transitionState() public {}
}
