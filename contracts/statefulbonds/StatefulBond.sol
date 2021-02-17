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
import '@settlemint/enteth-contracts/contracts/tokens/ERC20/ERC20Token.sol';

/**
 * StatefulBond
 *
A screen to create a bond as an asset on the platform with the following attributes:
Issuance Date
Launch Date
Maturity Date
Coupon Rate
Coupon Payment Frequency
ISIN
Bond Name
Bind Currency

Operator 1 can create the bond, and Operator 2 will approve the bond creation.

A screen which shows the amount of bonds which the client is holding with SCB (Maximum Bond field which Rod
mentioned earlier and this field can be updated as and when the client buy more bonds in the real world).
From this screen, Operator 1 can choose to tokenize the number of bonds and the number of tokens they want
to create. Operator 2 will approve the request and the tokens will be minted to a client wallet which Operator 2
will select from a list of wallets.

A screen to transfer tokens from the client wallet to other wallets and vice versa.

A screen for Coupon Payout with the following details:
Coupon Rate
Coupon Payment $Amount per Token
Total Coupon Payment $Amount
“Payment in Currency Token” Button
“Payment in Fiat Currency” Button

Operator 1 will clicked on either (d) or (e) button after confirming the details on the screen. When Operator 1
clicked on the button in (d), currency tokens will be paid out to the respective investor wallets. When Operator 1
clicked on the button in (e), an instruction will be sent to an external payment system. No need to have any external
connection, just need to show a pop-up etc to say that “Coupon Payment Instruction sent”

Bonus:

In-Flight Bonds – Bonds which are purchased by client in the real world but not yet settled. Client wants these in-flight bonds to be tokenized as well so that they can start to sell those tokens. When the actual bonds are settled in the real world, the in-flight bonds and the in-flight bond tokens become normal bonds and normal tokens through a change of status or any other logical way.

Thanks!




Fully manual yet stateful bond

States:

  - Created (ops1)
      - Issuance Date
      - Launch Date
      - Maturity Date
      - Coupon Rate
      - Coupon Payment Frequency
      - ISIN
      - Bond Name
      - Bind Currency
  - Approved (ops2)
  - Tokenization request (ops1)
      - max supply check
  - Tokenization approved (ops2)
      - mints to client

Functions:
  - updateMaxSupplyFromBackend()
  - createCoupon()

  - couponCheckpoints

Coupon

States:
  - Created (ops1)
      - Coupon Rate
      - Coupon Payment $Amount per Token
      - Total Coupon Payment $Amount
      - “Payment in Currency Token” Button
      - “Payment in Fiat Currency” Button
 *
 * @title State machine to track a stateful bond
 */
contract StatefulBond is Converter, StateMachine, FileFieldContainer, ERC20Token {
  // State Machine config
  bytes32 public constant STATE_CREATED = 'CREATED';
  bytes32 public constant STATE_TO_REVIEW = 'TO REVIEW';
  bytes32 public constant STATE_CHANGES_NEEDED = 'CHANGES NEEDED';
  bytes32 public constant STATE_READY_FOR_TOKENIZATION = 'READY FOR TOKENIZATION';
  bytes32 public constant STATE_TOKENIZATION_REQUEST = 'TOKENIZATION REQUEST';
  bytes32 public constant STATE_TOKENIZATION_APPROVED = 'TOKENIZATION APPROVED';
  bytes32 public constant STATE_TOKENIZATION_DENIED = 'TOKENIZATION DENIED';
  bytes32 public constant STATE_MATURED = 'MATURED';
  bytes32 public constant STATE_CONVERTED = 'CONVERTED';

  bytes32 public constant ROLE_ADMIN = 'ROLE_ADMIN';
  bytes32 public constant ROLE_MAKER = 'ROLE_MAKER';
  bytes32 public constant ROLE_CHECKER = 'ROLE_CHECKER';

  bytes32[] public _roles = [ROLE_ADMIN, ROLE_MAKER, ROLE_CHECKER];
  bytes32[] private _canEdit = [ROLE_ADMIN, ROLE_MAKER];

  // Data fields
  uint256 public _parValue;
  uint256 public _couponRate;
  uint256 public _launchDate;
  uint256 public _tokenizationAmount;
  address public _tokenizationRecipient;
  bytes32 public _inFlight;
  bytes32 public _frequency;
  uint8 internal _parValueDecimal;
  uint8 internal _couponRateDecimal;

  constructor(
    string memory name,
    uint256 parValue,
    uint256 couponRate,
    uint8 decimals,
    bytes32 inFlight,
    bytes32 frequency,
    GateKeeper gateKeeper,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public ERC20Token(name, decimals, address(gateKeeper), uiFieldDefinitionsHash) {
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    _parValue = parValue;
    _couponRate = couponRate;
    _inFlight = inFlight;
    _frequency = frequency;
    _parValueDecimal = 2;
    _couponRateDecimal = 2;
    setupStateMachine();
  }

  function canEdit() public view returns (bytes32[] memory) {
    return _canEdit;
  }

  function getDecimalsFor(bytes memory fieldName) public view override returns (uint256) {
    if (keccak256(fieldName) == keccak256('_parValue') || keccak256(fieldName) == keccak256('payment')) {
      return _parValueDecimal;
    }
    if (keccak256(fieldName) == keccak256('_couponRate')) {
      return _couponRateDecimal;
    }
    if (
      keccak256(fieldName) == keccak256('amount') ||
      keccak256(fieldName) == keccak256('balance') ||
      keccak256(fieldName) == keccak256('totalSupply') ||
      keccak256(fieldName) == keccak256('value') ||
      keccak256(fieldName) == keccak256('tokenizationAmount') ||
      keccak256(fieldName) == keccak256('_tokenizationAmount') ||
      keccak256(fieldName) == keccak256('holderBalance')
    ) {
      return _decimals;
    }
    return 0;
  }

  function edit(
    string memory name,
    uint256 parValue,
    uint256 couponRate,
    uint8 decimals,
    bytes32 inFlight,
    bytes32 frequency,
    string memory ipfsFieldContainerHash
  ) public authManyWithCustomReason(_canEdit, 'Edit requires one of roles: ROLE_ADMIN, ROLE_MAKER') {
    _name = name;
    _decimals = decimals;
    _parValue = parValue;
    _couponRate = couponRate;
    _inFlight = inFlight;
    _frequency = frequency;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  /**
   * @notice Releases the issuance to investors at a certain date and time
   *
   * @param launchDate the launch date or announcement date is the date at which the details regarding a new issue
   *                   are released to investors.
   */
  function launch(uint256 launchDate) public {
    require(_launchDate == 0, 'This bond is already launched');
    _launchDate = launchDate;
  }

  function requestTokenization(uint256 amount) public checkAllowedFunction {
    _tokenizationAmount = amount;
    _tokenizationRecipient = msg.sender;
  }

  function tokenize(bytes32 fromState, bytes32 toState) public checkAllowedFunction {
    mint(_tokenizationRecipient, _tokenizationAmount);
    reset(fromState, toState);
  }

  event PaymentCommand(address to, uint256 holderBalance, uint256 payment);

  function mature(
    bytes32, /* fromState */
    bytes32 /* toState */
  ) public {
    for (uint256 j = 0; j < tokenHolders.length; j++) {
      uint256 holderBalance = balances[tokenHolders[j]].balance;
      burn(tokenHolders[j], holderBalance);
      uint256 payment = holderBalance.mul(_parValue).div(10**uint256(getDecimalsFor('holderBalance')));
      emit PaymentCommand(tokenHolders[j], holderBalance, payment);
    }
  }

  function convert(
    bytes32, /* fromState */
    bytes32 /* toState */
  ) public {
    _inFlight = 'NO';
    transitionState(STATE_READY_FOR_TOKENIZATION);
  }

  function coupon() public checkAllowedFunction {
    bytes32 semi = 'SEMI';
    // .mul(1000) is used to avoid rounding issues. .div(1000) is done below in the payment calculation
    uint256 couponValue = _parValue.mul(1000).mul(_couponRate).div(100).div(10**uint256(getDecimalsFor('_couponRate')));
    if (_frequency == semi) {
      couponValue = couponValue.div(2);
    }
    for (uint256 j = 0; j < tokenHolders.length; j++) {
      uint256 holderBalance = balances[tokenHolders[j]].balance;
      uint256 payment = holderBalance.mul(couponValue).div(10**uint256(getDecimalsFor('holderBalance'))).div(1000);
      emit PaymentCommand(tokenHolders[j], holderBalance, payment);
    }
  }

  function reset(
    bytes32, /* fromState */
    bytes32 /* toState */
  ) public checkAllowedFunction {
    _tokenizationAmount = 0;
    _tokenizationRecipient = address(0x0);
    transitionState(STATE_READY_FOR_TOKENIZATION);
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
    createState(STATE_CREATED);
    createState(STATE_TO_REVIEW);
    createState(STATE_READY_FOR_TOKENIZATION);
    createState(STATE_CHANGES_NEEDED);
    createState(STATE_TOKENIZATION_REQUEST);
    createState(STATE_TOKENIZATION_DENIED);
    createState(STATE_TOKENIZATION_APPROVED);
    if (_inFlight == 'YES') {
      createState(STATE_CONVERTED);
    }
    createState(STATE_MATURED);

    // STATE_CREATED
    addNextStateForState(STATE_CREATED, STATE_TO_REVIEW);
    addAllowedFunctionForState(STATE_CREATED, this.edit.selector);

    // STATE_TO_REVIEW
    addRoleForState(STATE_TO_REVIEW, ROLE_ADMIN);
    addRoleForState(STATE_TO_REVIEW, ROLE_MAKER);
    addNextStateForState(STATE_TO_REVIEW, STATE_READY_FOR_TOKENIZATION);
    addNextStateForState(STATE_TO_REVIEW, STATE_CHANGES_NEEDED);

    // STATE_CHANGES_NEEDED
    addRoleForState(STATE_CHANGES_NEEDED, ROLE_ADMIN);
    addRoleForState(STATE_CHANGES_NEEDED, ROLE_CHECKER);
    addNextStateForState(STATE_CHANGES_NEEDED, STATE_TO_REVIEW);
    addAllowedFunctionForState(STATE_CHANGES_NEEDED, this.edit.selector);

    // STATE_READY_FOR_TOKENIZATION
    setPreFunctionForState(STATE_READY_FOR_TOKENIZATION, this.launch.selector);
    addRoleForState(STATE_READY_FOR_TOKENIZATION, ROLE_ADMIN);
    addRoleForState(STATE_READY_FOR_TOKENIZATION, ROLE_CHECKER);
    addNextStateForState(STATE_READY_FOR_TOKENIZATION, STATE_TOKENIZATION_REQUEST);
    if (_inFlight == 'YES') {
      addNextStateForState(STATE_READY_FOR_TOKENIZATION, STATE_CONVERTED);
    }
    addNextStateForState(STATE_READY_FOR_TOKENIZATION, STATE_MATURED);
    addAllowedFunctionForState(STATE_READY_FOR_TOKENIZATION, this.requestTokenization.selector);
    addAllowedFunctionForState(STATE_READY_FOR_TOKENIZATION, this.coupon.selector);
    addAllowedFunctionForState(STATE_READY_FOR_TOKENIZATION, this.transfer.selector);

    // STATE_TOKENIZATION_REQUEST
    setPreFunctionForState(STATE_TOKENIZATION_REQUEST, this.requestTokenization.selector);
    addRoleForState(STATE_TOKENIZATION_REQUEST, ROLE_ADMIN);
    addRoleForState(STATE_TOKENIZATION_REQUEST, ROLE_MAKER);
    addNextStateForState(STATE_TOKENIZATION_REQUEST, STATE_TOKENIZATION_APPROVED);
    addAllowedFunctionForState(STATE_TOKENIZATION_REQUEST, this.transfer.selector);
    addNextStateForState(STATE_TOKENIZATION_REQUEST, STATE_TOKENIZATION_DENIED);

    // STATE_TOKENIZATION_DENIED // auto advance
    addRoleForState(STATE_TOKENIZATION_DENIED, ROLE_ADMIN);
    addRoleForState(STATE_TOKENIZATION_DENIED, ROLE_CHECKER);
    addNextStateForState(STATE_TOKENIZATION_DENIED, STATE_READY_FOR_TOKENIZATION);
    addCallbackForState(STATE_TOKENIZATION_DENIED, reset);
    addAllowedFunctionForState(STATE_TOKENIZATION_DENIED, this.transfer.selector);
    addAllowedFunctionForState(STATE_TOKENIZATION_DENIED, this.reset.selector);
    addAllowedFunctionForState(STATE_TOKENIZATION_DENIED, this.transitionState.selector);

    // STATE_TOKENIZATION_APPROVED // auto advance
    addRoleForState(STATE_TOKENIZATION_APPROVED, ROLE_ADMIN);
    addRoleForState(STATE_TOKENIZATION_APPROVED, ROLE_CHECKER);
    addNextStateForState(STATE_TOKENIZATION_APPROVED, STATE_READY_FOR_TOKENIZATION);
    addCallbackForState(STATE_TOKENIZATION_APPROVED, tokenize);
    addAllowedFunctionForState(STATE_TOKENIZATION_APPROVED, this.tokenize.selector);
    addAllowedFunctionForState(STATE_TOKENIZATION_APPROVED, this.mint.selector);
    addAllowedFunctionForState(STATE_TOKENIZATION_APPROVED, this.transitionState.selector);
    addAllowedFunctionForState(STATE_TOKENIZATION_APPROVED, this.transfer.selector);
    addAllowedFunctionForState(STATE_TOKENIZATION_APPROVED, this.mature.selector);
    addAllowedFunctionForState(STATE_TOKENIZATION_APPROVED, this.reset.selector);

    if (_inFlight == 'YES') {
      // STATE_CONVERTED
      addRoleForState(STATE_CONVERTED, ROLE_ADMIN);
      addRoleForState(STATE_CONVERTED, ROLE_CHECKER);
      addCallbackForState(STATE_CONVERTED, convert);
      addAllowedFunctionForState(STATE_CONVERTED, this.convert.selector);
      addAllowedFunctionForState(STATE_CONVERTED, this.burn.selector);
      addNextStateForState(STATE_CONVERTED, STATE_READY_FOR_TOKENIZATION);
    }

    // STATE_MATURED
    addRoleForState(STATE_MATURED, ROLE_ADMIN);
    addRoleForState(STATE_MATURED, ROLE_CHECKER);
    addCallbackForState(STATE_MATURED, mature);
    addAllowedFunctionForState(STATE_MATURED, this.burn.selector);

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
  function getByIndex(uint256 index) public view returns (address holder, uint256 balance) {
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
  function getByKey(address key) public view returns (address holder, uint256 balance) {
    holder = key;
    balance = balances[key].balance;
  }
}
