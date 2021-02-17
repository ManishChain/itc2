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

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@settlemint/enteth-contracts/contracts/authentication/Secured.sol';
import '@settlemint/enteth-contracts/contracts/utility/metadata/IpfsFieldContainer.sol';

contract OmnibusToken is Secured, IpfsFieldContainer {
  using SafeMath for uint256;

  struct TokenAccount {
    uint256 balance;
    uint256 firstTransaction;
  }

  bytes32 internal constant MINT_ROLE = 'MINT_ROLE';
  bytes32 internal constant BURN_ROLE = 'BURN_ROLE';

  mapping(string => TokenAccount) public balances;
  string[] public tokenHolders;
  string internal _name;
  string internal _symbol;
  uint8 internal _decimals;
  uint256 internal _tSupply;

  constructor(
    string memory name,
    string memory symbol,
    uint8 decimals,
    address gateKeeper
  ) public Secured(gateKeeper) {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
  }

  struct TransactionDetail {
    string recipient;
    string sender;
    bytes32 transactionType;
    uint256 amount;
    uint256 price;
    string comment;
  }

  TransactionDetail[] public transactionHistory;
  uint256 internal totalFunds;

  function recordTransaction(
    string memory recipient,
    string memory sender,
    uint256 amount,
    uint256 price,
    bytes32 transactionType,
    string memory comment
  ) internal {
    transactionHistory.push();
    uint256 index = transactionHistory.length;
    TransactionDetail storage t = transactionHistory[index - 1];
    t.recipient = recipient;
    t.sender = sender;
    t.transactionType = transactionType;
    t.amount = amount;
    t.price = price;
    t.comment = comment;

    totalFunds.add(price);
  }

  event Transfer(string sender, string recipient, uint256 amount);
  event Burn(string indexed account, uint256 amount);
  event Mint(string indexed account, uint256 amount);

  /**
   * @dev Returns the name of the token.
   */
  function name() public view returns (string memory) {
    return _name;
  }

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the
   * name or an ISIN.
   */
  function symbol() public view returns (string memory) {
    return _symbol;
  }

  /**
   * @dev Returns the number of decimals used to get its user representation.
   * For example, if `decimals` equals `2`, a balance of `505` tokens should
   * be displayed to a user as `5,05` (`505 / 10 ** 2`).
   *
   * Tokens usually opt for a value of 18, imitating the relationship between
   * Ether and Wei.
   *
   * NOTE: This information is only used for _display_ purposes: it in
   * no way affects any of the arithmetic of the contract, including
   * balanceOf and transfer.
   */
  function decimals() public view returns (uint8) {
    return _decimals;
  }

  /**
   * @dev Returns the amount of tokens in existence.
   */
  function totalSupply() public view returns (uint256) {
    return _tSupply;
  }

  /**
   * @dev Returns the amount of tokens owned by `account`.
   */
  function balanceOf(string memory account) public view returns (uint256) {
    return balances[account].balance;
  }

  /**
   * @dev Moves `amount` tokens from `sender` to `recipient`.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `sender` and `recipient` cannot be empty.
   * - `sender` must have a balance of at least `amount`.
   */
  function transfer(
    string memory sender,
    string memory recipient,
    uint256 amount,
    uint256 price
  ) public virtual returns (bool success) {
    require(bytes(sender).length > 0, 'OmnibusToken: transfer from an empty account');
    require(bytes(recipient).length > 0, 'OmnibusToken: transfer to  an empty account');
    if (balances[sender].firstTransaction == 0) {
      balances[sender].firstTransaction = now;
      tokenHolders.push(sender);
    }
    if (balances[recipient].firstTransaction == 0) {
      balances[recipient].firstTransaction = now;
      tokenHolders.push(recipient);
    }
    TokenAccount storage senderBalance = balances[sender];
    TokenAccount storage recipientBalance = balances[recipient];
    senderBalance.balance = senderBalance.balance.sub(amount, 'OmnibusToken: transfer amount exceeds balance');
    recipientBalance.balance = recipientBalance.balance.add(amount);
    recordTransaction(recipient, sender, amount, price, bytes32('TRANSFER'), '');
    success = true;

    emit Transfer(sender, recipient, amount);
  }

  /** @dev Creates `amount` te total supply.
   *
   * Emits a {Mint} event
   *
   * Requirements
   *
   * - minted tokens must not cause the total supply to go over the cap.
   */
  function mint(
    string memory account,
    uint256 amount,
    uint256 price
  ) public virtual authWithCustomReason(MINT_ROLE, 'Caller needs MINT_ROLE') returns (bool success) {
    require(bytes(account).length > 0, 'OmnibusToken: mint to an empty account');
    if (balances[account].firstTransaction == 0) {
      balances[account].firstTransaction = now;
      tokenHolders.push(account);
    }
    _tSupply = _tSupply.add(amount);
    TokenAccount storage accountBalance = balances[account];
    accountBalance.balance = accountBalance.balance.add(amount);
    recordTransaction(account, 'WEALTH MANAGEMENT', amount, price, bytes32('MINT'), '');
    success = true;
    emit Mint(account, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`, reducing the
   * total supply.
   *
   * Emits a {Burn} event.
   *
   * Requirements
   *
   * - `account` cannot be empty.
   * - `account` must have at least `amount` tokens.
   */
  function burn(
    string memory account,
    uint256 amount,
    uint256 price
  ) public virtual authWithCustomReason(BURN_ROLE, 'Caller needs BURN_ROLE') returns (bool success) {
    require(bytes(account).length > 0, 'OmnibusToken: burn from an empty account');
    TokenAccount storage accountBalance = balances[account];
    accountBalance.balance = accountBalance.balance.sub(amount, 'OmnibusToken: burn amount exceeds balance');
    _tSupply = _tSupply.sub(amount);
    recordTransaction(account, 'WEALTH MANAGEMENT', amount, price, bytes32('BURN'), '');
    success = true;
    emit Burn(account, amount);
  }
}
