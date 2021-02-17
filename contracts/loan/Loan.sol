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

import '@settlemint/enteth-contracts/contracts/tokens/ERC20/ERC20Token.sol';

/**
 * @title Fungible token that records repayments.
 */
contract Loan is ERC20Token {
  constructor(
    string memory name,
    uint8 decimals,
    address gateKeeper,
    string memory uiFieldDefinitionsHash
  ) public ERC20Token(name, decimals, gateKeeper, uiFieldDefinitionsHash) {}

  struct LoanMetrics {
    uint256 loaned;
    uint256 repayed;
  }

  mapping(address => LoanMetrics) public loans;

  bytes32 public constant REPAY_ROLE = 'REPAY_ROLE';
  bytes32 public constant EDIT_ROLE = 'EDIT_ROLE';

  event Repayment(address from, uint256 value);

  function getDecimalsFor(
    bytes memory /*fieldName*/
  ) public view override returns (uint256) {
    return _decimals;
  }

  /**
   * @notice Updates the token's name and number of decimals
   * @dev Restricted to user with the "EDIT_ROLE" permission
   * @param name the token's new name
   * @param decimals the token's new number of decimals
   */
  function edit(string memory name, uint8 decimals) public auth(EDIT_ROLE) {
    _name = name;
    _decimals = decimals;
  }

  /**
   * @notice Increases the amount borrowed for an address
   * @param to the address of the borrower
   * @param amount the amount borrowed
   * @return success a boolean value indicating success or failure
   */
  function mint(address to, uint256 amount) public override auth(MINT_ROLE) returns (bool success) {
    loans[to].loaned = loans[to].loaned.add(amount);
    return super.mint(to, amount);
  }

  /**
   * @notice Increases the amount repayed for an address
   * @param from the address of the borrower
   * @param amount the amount repayed
   * @return success a boolean value indicating success or failure
   */
  function repay(address from, uint256 amount) public auth(REPAY_ROLE) returns (bool success) {
    loans[from].repayed = loans[from].repayed.add(amount);
    emit Repayment(from, amount);
    return true;
  }

  /**
   * @notice Returns the outstanding amount borrowed for an address
   * @param owner the address of the borrower
   * @return outstanding the outstanding amount borrowed
   */
  function outstandingOf(address owner) public view returns (int256 outstanding) {
    return int256(loans[owner].loaned - loans[owner].repayed);
  }

  /**
   * @notice Returns the amount of tokenholders recorded in this contract
   * @dev Gets the amount of token holders, used by the middleware to build a cache you can query. You should not need this function in general since iteration this way clientside is very slow.
   * @return length An uint256 representing the amount of tokenholders recorded in this contract.
   */
  function getIndexLength() public view override returns (uint256 length) {
    length = tokenHolders.length;
  }

  /**
   * @notice Returns the address and balance of the tokenholder by index
   * @param index used to access the tokenHolders array
   * @return holder holder's address, balance, amount loaned and amount repayed
   */
  function getByIndex(uint256 index)
    public
    view
    returns (
      address holder,
      uint256 balance,
      uint256 loaned,
      uint256 repayed
    )
  {
    holder = tokenHolders[index];
    balance = balances[tokenHolders[index]].balance;
    loaned = loans[tokenHolders[index]].loaned;
    repayed = loans[tokenHolders[index]].repayed;
  }

  /**
   * @notice Returns the address and balance of the tokenholder by address
   * @param key used to access the token's balances and loans properties
   * @return holder holder's address, balance, amount loaned and amount repayed
   */
  function getByKey(address key)
    public
    view
    returns (
      address holder,
      uint256 balance,
      uint256 loaned,
      uint256 repayed
    )
  {
    holder = key;
    balance = balances[key].balance;
    loaned = loans[key].loaned;
    repayed = loans[key].repayed;
  }
}
