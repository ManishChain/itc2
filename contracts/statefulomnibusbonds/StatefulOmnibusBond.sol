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

import '@settlemint/enteth-contracts/contracts/authentication/Secured.sol';
import '@settlemint/enteth-contracts/contracts/provenance/statemachine/StateMachine.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/IpfsFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/FileFieldContainer.sol';
import '@settlemint/enteth-contracts/contracts/utility/conversions/Converter.sol';
import '@settlemint/enteth-contracts/contracts/tokens/IWithDecimalFields.sol';
import '@settlemint/enteth-contracts/contracts/utility/syncing/Syncable.sol';
import '../omnibustoken/OmnibusToken.sol';

/**
 * StatefulOmnibusBond
 *
 * @title State machine to track a stateful omnibus bond
 */
contract StatefulOmnibusBond is
  Converter,
  StateMachine,
  FileFieldContainer,
  OmnibusToken,
  IWithDecimalFields,
  Syncable
{
  // State Machine config
  bytes32 public constant STATE_CREATED = 'STATE_CREATED';
  bytes32 public constant STATE_TO_REVIEW = 'STATE_TO_REVIEW';
  bytes32 public constant STATE_ACTIVE = 'STATE_ACTIVE';
  bytes32 public constant STATE_MATURED = 'STATE_MATURED';
  bytes32 public constant STATE_CHANGES_NEEDED = 'STATE_CHANGES_NEEDED';

  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_MAKER = 'ROLE_MAKER';
  bytes32 public constant ROLE_CHECKER = 'ROLE_CHECKER';

  bytes32[] public _roles = [ROLE_ADMIN, ROLE_MAKER, ROLE_CHECKER];
  bytes32[] private _roleMaker = [ROLE_ADMIN, ROLE_MAKER];
  bytes32[] private _roleChecker = [ROLE_ADMIN, ROLE_CHECKER];

  uint256 public _parValue;
  uint256 public _couponRate;
  uint256 public _launchDate;
  bytes32 public _frequency;
  uint8 internal _parValueDecimal;
  uint8 internal _couponRateDecimal;
  string public _uiFieldDefinitionsHash;
  address public _bondManagerAddress;

  mapping(uint256 => mapping(string => TokenAccount)) private balancesAtCouponTime;
  uint256[] private couponTimes;

  struct InflightAccount {
    uint256 balance;
    string nextInLine;
    string previousInLine;
  }
  mapping(string => InflightAccount) internal inflightBalances;
  uint256 internal _inflightTotalSupply;
  string firstInflightInline;
  string lastInflightInline;

  event Payment(string to, uint256 holderBalance, uint256 payment, string comment);
  event ChangesNeededWithComment(string comment);
  event CONVERTED_INFLIGHT_TO_SETTLED(string holder, uint256 amount);

  constructor(
    string memory name,
    string memory symbol,
    uint256 parValue,
    uint256 couponRate,
    uint8 decimals,
    bytes32 frequency,
    GateKeeper gateKeeper,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public OmnibusToken(name, symbol, decimals, address(gateKeeper)) {
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _uiFieldDefinitionsHash = uiFieldDefinitionsHash;
    _parValue = parValue;
    _couponRate = couponRate;
    _frequency = frequency;
    _parValueDecimal = 2;
    _couponRateDecimal = 2;
    setupStateMachine();
  }

  function canEdit() public view returns (bytes32[] memory) {
    return _roleMaker;
  }

  function getDecimalsFor(bytes memory fieldName) public view override returns (uint256) {
    if (
      keccak256(fieldName) == keccak256('_parValue') ||
      keccak256(fieldName) == keccak256('payment') ||
      keccak256(fieldName) == keccak256('price')
    ) {
      return _parValueDecimal;
    }
    if (keccak256(fieldName) == keccak256('_couponRate')) {
      return _couponRateDecimal;
    }
    if (
      keccak256(fieldName) == keccak256('amount') ||
      keccak256(fieldName) == keccak256('balance') ||
      keccak256(fieldName) == keccak256('totalSupply') ||
      keccak256(fieldName) == keccak256('inflightTotal') ||
      keccak256(fieldName) == keccak256('value') ||
      keccak256(fieldName) == keccak256('holderBalance')
    ) {
      return _decimals;
    }
  }

  function setBondManagerAddress(address bondManagerAddress) public {
    _bondManagerAddress = bondManagerAddress;
  }

  function edit(
    string memory name,
    string memory symbol,
    uint256 parValue,
    uint256 couponRate,
    uint8 decimals,
    bytes32 frequency,
    string memory ipfsFieldContainerHash
  ) public authManyWithCustomReason(_roleMaker, 'Edit requires one of roles: ROLE_ADMIN, ROLE_MAKER') {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
    _parValue = parValue;
    _couponRate = couponRate;
    _frequency = frequency;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  /**
   * @notice Releases the issuance to investors at a certain date and time
   *
   *                   are released to investors.
   */
  function launch(bytes32, bytes32) public {
    require(_launchDate == 0, 'This bond is already launched');
    _launchDate = block.timestamp;
  }

  function coupon(string memory comment)
    public
    authManyWithCustomReason(_roleMaker, 'coupon needs ROLE_ADMIN or ROLE_MAKER')
    checkAllowedFunction
  {
    bytes32 semi = 'SEMI';
    // .mul(1000) is used to avoid rounding issues. .div(1000) is done below in the payment calculation
    uint256 couponValue = _parValue.mul(1000).mul(_couponRate).div(100).div(10**uint256(getDecimalsFor('_couponRate')));

    uint256 blocktime = now;

    if (_frequency == semi) {
      couponValue = couponValue.div(2);
    }
    for (uint256 j = 0; j < tokenHolders.length; j++) {
      uint256 holderBalance = balances[tokenHolders[j]].balance;
      uint256 payment = holderBalance.mul(couponValue).div(10**uint256(getDecimalsFor('holderBalance'))).div(1000);

      // Save balances at this blocktime
      balancesAtCouponTime[blocktime][tokenHolders[j]] = balances[tokenHolders[j]];

      recordTransaction(tokenHolders[j], 'WEALTH MANAGEMENT', payment, 0, bytes32('COUPON PAYMENT'), comment);
      emit Payment(tokenHolders[j], holderBalance, payment, comment);
    }
    couponTimes.push(blocktime);
  }

  function mature(
    bytes32, /* fromState */
    bytes32 /* toState */
  ) public authManyWithCustomReason(_roleChecker, 'mature needs ROLE_ADMIN or ROLE_CHECKER') {
    uint256 blocktime = now;

    for (uint256 j = 0; j < tokenHolders.length; j++) {
      uint256 holderBalance = balances[tokenHolders[j]].balance;

      // Save balances at this blocktime
      balancesAtCouponTime[blocktime][tokenHolders[j]] = balances[tokenHolders[j]];

      burn(tokenHolders[j], holderBalance, 0);
      uint256 payment = holderBalance.mul(_parValue).div(10**uint256(getDecimalsFor('holderBalance')));
      emit Payment(tokenHolders[j], holderBalance, payment, 'MATURITY');
    }
    couponTimes.push(blocktime);
  }

  function changesNeededWithComment(string memory comment)
    public
    checkAllowedFunction
    authManyWithCustomReason(
      _roleChecker,
      'Set to STATE_CHANGES_NEEDED requires one of roles: ROLE_ADMIN or ROLE_CHECKER'
    )
  {
    transitionState(STATE_CHANGES_NEEDED);
    emit ChangesNeededWithComment(comment);
  }

  function isInActiveState() public view returns (bool) {
    return getCurrentState() == STATE_ACTIVE;
  }

  /** @dev mints amount but also record inflight balances.
   *
   * needs MINT_ROLE as mint() will be called.
   * to be called by the BondManager
   */
  function mintInflight(
    string memory account,
    uint256 amount,
    uint256 price
  ) public returns (bool success) {
    InflightAccount storage inflightAccount = inflightBalances[account];
    if (inflightAccount.balance == 0) {
      InflightAccount storage lastInflightInlineAccount = inflightBalances[lastInflightInline];
      InflightAccount storage firstInflightInlineAccount = inflightBalances[firstInflightInline];
      if (firstInflightInlineAccount.balance == 0) {
        firstInflightInline = account;
      }
      lastInflightInlineAccount.nextInLine = account;
      inflightAccount.previousInLine = lastInflightInline;
      lastInflightInline = account;
    }
    inflightAccount.balance = inflightAccount.balance.add(amount);
    _inflightTotalSupply = _inflightTotalSupply.add(amount);

    success = mint(account, amount, price);
  }

  /** @dev converts a certain amount of inflight to not inflight. Decrease the inflight balances based on FIFO.
   *
   * to be called by the BondManager
   */
  function convertInflight(uint256 amount)
    public
    authWithCustomReason(MINT_ROLE, 'Caller needs MINT_ROLE')
    returns (bool success)
  {
    uint256 remainingAmount = amount;
    while (remainingAmount > 0) {
      InflightAccount storage firstInflightInlineAccount = inflightBalances[firstInflightInline];
      if (firstInflightInlineAccount.balance < remainingAmount) {
        remainingAmount = remainingAmount.sub(firstInflightInlineAccount.balance);
        emit CONVERTED_INFLIGHT_TO_SETTLED(firstInflightInline, firstInflightInlineAccount.balance);
        firstInflightInlineAccount.balance = 0;
      } else {
        firstInflightInlineAccount.balance = firstInflightInlineAccount.balance.sub(remainingAmount);
        emit CONVERTED_INFLIGHT_TO_SETTLED(firstInflightInline, remainingAmount);
        remainingAmount = 0;
      }
      if (firstInflightInlineAccount.balance == 0) {
        firstInflightInline = firstInflightInlineAccount.nextInLine;
        inflightBalances[firstInflightInline].previousInLine = '';
        if (keccak256(abi.encodePacked(firstInflightInline)) == keccak256(abi.encodePacked(''))) {
          // empty
          lastInflightInline = '';
        }
        firstInflightInlineAccount.previousInLine = '';
        firstInflightInlineAccount.nextInLine = '';
      }
    }

    _inflightTotalSupply = _inflightTotalSupply.sub(amount);

    success = true;
  }

  /** @dev burn a certain amount of inflight tokens. Decrease the inflight balances based on LIFO.
   *
   * needs BURN_ROLE as burn() will be called.
   * to be called by the BondManager
   */
  function burnInflight(uint256 amount)
    public
    authWithCustomReason(BURN_ROLE, 'Caller needs BURN_ROLE')
    returns (bool success)
  {
    uint256 remainingAmount = amount;
    while (remainingAmount > 0) {
      InflightAccount storage lastInflightInlineAccount = inflightBalances[lastInflightInline];
      if (lastInflightInlineAccount.balance < remainingAmount) {
        remainingAmount = remainingAmount.sub(lastInflightInlineAccount.balance);
        burn(lastInflightInline, lastInflightInlineAccount.balance, 0);
        lastInflightInlineAccount.balance = 0;
      } else {
        lastInflightInlineAccount.balance = lastInflightInlineAccount.balance.sub(remainingAmount);
        burn(lastInflightInline, remainingAmount, 0);
        remainingAmount = 0;
      }
      if (lastInflightInlineAccount.balance == 0) {
        lastInflightInline = lastInflightInlineAccount.previousInLine;
        inflightBalances[lastInflightInline].nextInLine = '';
        if (keccak256(abi.encodePacked(lastInflightInline)) == keccak256(abi.encodePacked(''))) {
          // empty
          firstInflightInline = '';
        }
        lastInflightInlineAccount.previousInLine = '';
        lastInflightInlineAccount.nextInLine = '';
      }
    }

    _inflightTotalSupply = _inflightTotalSupply.sub(amount);

    success = true;
  }

  function transfer(
    string memory sender,
    string memory recipient,
    uint256 amount,
    uint256 price
  )
    public
    override
    authManyWithCustomReason(_roleMaker, 'transfer needs ROLE_ADMIN or ROLE_MAKER')
    returns (bool success)
  {
    InflightAccount storage senderInflightAccount = inflightBalances[sender];
    uint256 settledSenderBalance = balances[sender].balance.sub(senderInflightAccount.balance);
    uint256 inflightBalanceToBeTransfered = 0;
    if (settledSenderBalance < amount) {
      inflightBalanceToBeTransfered = amount.sub(settledSenderBalance);
    }

    success = super.transfer(sender, recipient, amount, price);

    if (inflightBalanceToBeTransfered > 0) {
      // decrease inflight balance of sender
      senderInflightAccount.balance = senderInflightAccount.balance.sub(inflightBalanceToBeTransfered);
      if (senderInflightAccount.balance == 0) {
        // remove sender from queue
        if (keccak256(abi.encodePacked(senderInflightAccount.previousInLine)) == keccak256(abi.encodePacked(''))) {
          // empty
          firstInflightInline = senderInflightAccount.nextInLine;
        }
        if (keccak256(abi.encodePacked(senderInflightAccount.nextInLine)) == keccak256(abi.encodePacked(''))) {
          // empty
          lastInflightInline = senderInflightAccount.previousInLine;
        }
        inflightBalances[senderInflightAccount.previousInLine].nextInLine = senderInflightAccount.nextInLine;
        inflightBalances[senderInflightAccount.nextInLine].previousInLine = senderInflightAccount.previousInLine;
        senderInflightAccount.previousInLine = '';
        senderInflightAccount.nextInLine = '';
      }

      // increase inflight balance of recipient
      InflightAccount storage recipientInflightAccount = inflightBalances[recipient];
      if (recipientInflightAccount.balance == 0) {
        // add recipient to queue
        inflightBalances[lastInflightInline].nextInLine = recipient;
        recipientInflightAccount.previousInLine = lastInflightInline;
        lastInflightInline = recipient;
        if (keccak256(abi.encodePacked(recipientInflightAccount.previousInLine)) == keccak256(abi.encodePacked(''))) {
          // empty
          firstInflightInline = recipient;
        }
      }
      recipientInflightAccount.balance = recipientInflightAccount.balance.add(inflightBalanceToBeTransfered);
    }
  }

  /**
   * @notice Returns all the roles for this contract
   * @return bytes32[] array of raw bytes representing the roles
   */
  function getRoles() public view returns (bytes32[] memory) {
    return _roles;
  }

  /**
   * @dev Returns the amount of inflight tokens.
   */
  function inflightTotal() public view returns (uint256) {
    return _inflightTotalSupply;
  }

  function setupStateMachine() internal override {
    //create all states
    createState(STATE_CREATED);
    createState(STATE_TO_REVIEW);
    createState(STATE_CHANGES_NEEDED);
    createState(STATE_ACTIVE);
    createState(STATE_MATURED);

    // STATE_CREATED
    addNextStateForState(STATE_CREATED, STATE_TO_REVIEW);
    addAllowedFunctionForState(STATE_CREATED, this.edit.selector);
    addRoleForState(STATE_CREATED, ROLE_MAKER);
    addRoleForState(STATE_CREATED, ROLE_ADMIN);

    // STATE_TO_REVIEW
    addNextStateForState(STATE_TO_REVIEW, STATE_CHANGES_NEEDED);
    addNextStateForState(STATE_TO_REVIEW, STATE_ACTIVE);
    addAllowedFunctionForState(STATE_TO_REVIEW, this.changesNeededWithComment.selector);
    addRoleForState(STATE_TO_REVIEW, ROLE_MAKER);
    addRoleForState(STATE_TO_REVIEW, ROLE_ADMIN);

    //  STATE_CHANGES_NEEDED
    addNextStateForState(STATE_CHANGES_NEEDED, STATE_TO_REVIEW);
    addAllowedFunctionForState(STATE_CHANGES_NEEDED, this.edit.selector);
    addRoleForState(STATE_CHANGES_NEEDED, ROLE_CHECKER);
    addRoleForState(STATE_CHANGES_NEEDED, ROLE_ADMIN);

    // STATE_ACTIVE
    addRoleForState(STATE_ACTIVE, ROLE_ADMIN);
    addRoleForState(STATE_ACTIVE, ROLE_CHECKER);
    addNextStateForState(STATE_ACTIVE, STATE_MATURED);
    addAllowedFunctionForState(STATE_ACTIVE, this.coupon.selector);
    addAllowedFunctionForState(STATE_ACTIVE, this.transfer.selector);
    addAllowedFunctionForState(STATE_ACTIVE, this.launch.selector);
    addAllowedFunctionForState(STATE_ACTIVE, this.mint.selector);
    addAllowedFunctionForState(STATE_ACTIVE, this.burn.selector);
    addAllowedFunctionForState(STATE_ACTIVE, this.mature.selector);
    addCallbackForState(STATE_ACTIVE, launch);

    // STATE_MATURED
    addRoleForState(STATE_MATURED, ROLE_ADMIN);
    addRoleForState(STATE_MATURED, ROLE_CHECKER);
    addCallbackForState(STATE_MATURED, mature);

    setInitialState(STATE_CREATED);
  }

  /**
   * @notice Returns the amount of bond holders.
   * @dev Gets the amount of bond holders, used by the middleware to build a cache you can query.
   *      You should not need this function in general since iteration this way clientside is very slow.
   *
   * @return length An uint256 representing the amount of tokenholders recorded in this contract.
   */
  function getIndexLength() public view override returns (uint256 length) {
    length = tokenHolders.length;
  }

  /**
   * @notice Returns the address and balance of the tokenholder by index
   * @dev Gets balance of an individual bond holder, used by the middleware to build a cache you can query.
   *      You should not need this function in general since iteration this way clientside is very slow.
   *
   * @param index       used to access the tokenHolders array
   * @return holder     holder's address
   * @return balance    the holder's balance
   */
  function getByIndex(uint256 index) public view returns (string memory holder, uint256 balance) {
    holder = tokenHolders[index];
    balance = balances[tokenHolders[index]].balance;
  }

  /**
   * @notice Returns the address and balance of the tokenholder by address
   * @dev Gets balance of an individual bond holder, used by the middleware to build a cache you can query.
   *      You should not need this function in general since iteration this way clientside is very slow.
   *
   * @param key         used to access the token's balances
   * @return holder     holder's address and balance
   * @return balance    the holder's balance
   */
  function getByKey(string memory key) public view returns (string memory holder, uint256 balance) {
    holder = key;
    balance = balances[key].balance;
  }

  function transactionHistoryList() public view returns (TransactionDetail[] memory) {
    return transactionHistory;
  }

  function getInflightList() public view returns (InflightAccount[] memory) {
    InflightAccount[] memory inflightAccounts = new InflightAccount[](tokenHolders.length);
    for (uint256 j = 0; j < tokenHolders.length; j++) {
      inflightAccounts[j] = inflightBalances[tokenHolders[j]];
    }
    return inflightAccounts;
  }

  struct AccountBalance {
    string accountID;
    uint256 balance;
  }

  struct BalancesAtCouponTime {
    uint256 couponTime;
    AccountBalance[] accountsBalances;
  }

  function getBalancesAtCouponTime() public view returns (BalancesAtCouponTime[] memory) {
    BalancesAtCouponTime[] memory arrayBalancesAtCouponTime = new BalancesAtCouponTime[](couponTimes.length);
    for (uint256 i = 0; i < couponTimes.length; i++) {
      arrayBalancesAtCouponTime[i].couponTime = couponTimes[i];
      AccountBalance[] memory accountBalances = new AccountBalance[](tokenHolders.length);
      for (uint256 j = 0; j < tokenHolders.length; j++) {
        accountBalances[j].accountID = tokenHolders[j];
        accountBalances[j].balance = balancesAtCouponTime[couponTimes[i]][tokenHolders[j]].balance;
      }
      arrayBalancesAtCouponTime[i].accountsBalances = accountBalances;
    }
    return arrayBalancesAtCouponTime;
  }
}
