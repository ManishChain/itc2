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

import '../currency/Currency.sol';
import '@settlemint/enteth-contracts/contracts/tokens/ERC20/ERC20Token.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

/**
 * IPFS Fields
 * - isin             ISIN are unique serial numbers for all bond offerings issued by the ISIN organization. ISIN is
 *                    a global catalogue of bonds and other securities.
 * - issuer           Issuer is the entity that is raising capital in the primary debt market.
 */

/**
 * @title Bond
 * @notice A bond is a debt security that corporations and governments use to raise capital. It provides an investor
 *         the means to loan money to an issuer for a defined period of time. In return, the investor will receive variable
 *         or fixed interest payments periodically throughout the loaning period.
 */
contract Bond is ERC20Token {
  using SafeMath for uint256;

  bytes32 public constant EDIT_ROLE = 'EDIT_ROLE';

  uint256 public _parValue;
  Currency public _parCurrency;
  uint256 public _issuanceDate;
  uint256 public _maturityPeriod;
  uint256 public _couponRate;
  uint256 private _couponAmountPerBondPerSixMonths;
  uint256 public _couponPeriod;
  uint256 private _numSixMonthsPerCoupon;
  uint256 public _launchDate;
  uint256 public _maturityDate;
  uint256 private month = 4 * 7 * 24 * 3600;
  uint256 private parDecimals;

  struct Coupon {
    bool inititated;
    uint256 totalCouponAmount;
    uint256 redeemedCouponAmount;
    address[] holdersAtCouponDate; // the list of addresses that held the bond at this coupon date
    uint256[] amountsAtCouponDate;
  }

  Coupon[] public _coupons;
  uint256[] public _couponDates;

  /**
   * @notice Creates a new bond
   *
   * @param name             A clear name of for the bond for humans.
   * @param parValue         The principal amount is the amount paid out to the holder of the bond at its maturity date.
   *                         It is also known as the “par value”. The principal amount is the reference amount used to
   *                         calculate interest payments. (amount * 10^decimals of the currency)
   * @param parCurrency      The currency of the par value
   * @param maturityPeriod   The maturity period is an amount of months after the issuance date when the bond matures and the
   *                         bond issuer must pay the principal amount to bondholders. (number of months after the issuance date)
   * @param couponRate       The coupon rate is the annual rate of interest (expressed as a percentage) the bond issuer
   *                         pays out to bondholders on the principal amount of the bond at each coupon payment date. Coupon
   *                         payments compensate investors for the risk of loaning capital to the issuer. (percentage * 100)
   * @param couponPeriod     The coupon period is the frequency that the bond issuer will make coupon payments to bondholders.
   *                         Typically, this is either semi-annual or annual. (number of months between coupons)
   * @param decimals         The granularity into which a single bond can be tokenized.
   * @param gateKeeper       The gatekeeper is the smart contract which handles the permissions on this bond.
   * @param ipfsFieldContainerHash The IPFS hash to all the fields that are not on chain.
   * @param uiFieldDefinitionsHash The IPFS hash to the field definitions for the UI
   */
  constructor(
    string memory name,
    uint256 parValue,
    Currency parCurrency,
    uint256 maturityPeriod,
    uint256 couponRate,
    uint256 couponPeriod,
    uint8 decimals,
    GateKeeper gateKeeper,
    string memory ipfsFieldContainerHash,
    string memory uiFieldDefinitionsHash
  ) public ERC20Token(name, decimals, address(gateKeeper), uiFieldDefinitionsHash) {
    require(
      (maturityPeriod / couponPeriod) * couponPeriod == maturityPeriod,
      'The maturity period needs to be a multiple of the coupon period'
    );
    _name = name;
    _parValue = parValue;
    _parCurrency = parCurrency;
    parDecimals = _parCurrency._decimals();
    _maturityPeriod = maturityPeriod;
    _couponRate = couponRate;
    _couponPeriod = couponPeriod;
    _numSixMonthsPerCoupon = couponPeriod.div(6);
    _couponAmountPerBondPerSixMonths = parValue.mul(couponRate.div(2)).div(100);
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
  }

  function getDecimalsFor(bytes memory fieldName) public view override returns (uint256) {
    if (keccak256(fieldName) == keccak256('parValue')) {
      return parDecimals;
    } else {
      return _decimals;
    }
  }

  /**
   * @notice Updates most of the settings of a bond if the bond has not launched yet and the user had the EDIT_ROLE.
   *
   * @param name             A clear name of for the bond for humans.
   * @param parValue         The principal amount is the amount paid out to the holder of the bond at its maturity date.
   *                         It is also known as the “par value”. The principal amount is the reference amount used to
   *                         calculate interest payments. (amount * 10^decimals of the currency)
   * @param parCurrency      The currency of the par value
   * @param maturityPeriod   The maturity period is an amount of months after the issuance date when the bond matures and the
   *                         bond issuer must pay the principal amount to bondholders. (number of months after the issuance date)
   * @param couponRate       The coupon rate is the annual rate of interest (expressed as a percentage) the bond issuer
   *                         pays out to bondholders on the principal amount of the bond at each coupon payment date. Coupon
   *                         payments compensate investors for the risk of loaning capital to the issuer. (percentage * 100)
   * @param couponPeriod     The coupon period is the frequency that the bond issuer will make coupon payments to bondholders.
   *                         Typically, this is either semi-annual or annual. (number of months between coupons)
   * @param decimals         The granularity into which a single bond can be tokenized.
   * @param ipfsFieldContainerHash The IPFS hash to all the fields that are not on chain.
   */
  function edit(
    string memory name,
    uint256 parValue,
    Currency parCurrency,
    uint256 maturityPeriod,
    uint256 couponRate,
    uint256 couponPeriod,
    uint8 decimals,
    string memory ipfsFieldContainerHash
  ) public auth(EDIT_ROLE) {
    require(
      _launchDate == 0 || now < _launchDate,
      'It is forbidden to edit a bond after it has been launched to the investors'
    );
    require(
      maturityPeriod % 6 == 0 && couponPeriod % 6 == 0,
      'The maturity and coupon period needs to be a multiple of the 6 months'
    );
    require(
      maturityPeriod >= couponPeriod,
      'The maturityPeriod period needs to be at least as long as the coupon period'
    );

    _name = name;
    _parValue = parValue;
    _parCurrency = parCurrency;
    parDecimals = _parCurrency._decimals();
    _maturityPeriod = maturityPeriod;
    _couponRate = couponRate;
    _couponPeriod = couponPeriod;
    _numSixMonthsPerCoupon = couponPeriod.div(6);
    _couponAmountPerBondPerSixMonths = parValue.mul(couponRate.div(2)).div(10**parDecimals);
    _decimals = decimals;
    _ipfsFieldContainerHash = ipfsFieldContainerHash;
    if (_issuanceDate > 0) {
      _maturityDate = _issuanceDate + _maturityPeriod * month;
    }
  }

  /**
   * @param issuanceDate     The date the bond is officially issued. This marks the start of the maturityPeriod (unix timestamp)
   */
  function setIssuanceDate(uint256 issuanceDate) public {
    require(
      _launchDate == 0 || now < _launchDate,
      'It is forbidden to edit a bond after it has been launched to the investors'
    );
    _issuanceDate = issuanceDate;
    _maturityDate = issuanceDate + _maturityPeriod * month;
  }

  /**
   * @notice Releases the issuance to investors at a certain date and time
   *
   * @param launchDate the launch date or announcement date is the date at which the details regarding a new issue
   *                   are released to investors.
   */
  function launch(uint256 launchDate) public {
    require(_launchDate == 0, 'This bond is already launched');
    require(_launchDate <= _issuanceDate, 'A bond can only be launched after or on the issuance date');
    _launchDate = launchDate;
    createCoupons();
  }

  /**
   * @notice Create the entries for the coupons.
   */
  function createCoupons() private {
    require(_coupons.length == 0, 'Coupons are already initialized, re-initialization is not allowed');
    uint256 amountOfCoupons = _maturityPeriod.div(_couponPeriod);
    for (uint256 i = 1; i <= amountOfCoupons; i++) {
      uint256 couponDate = _issuanceDate + i * (month * _couponPeriod);
      _couponDates.push(couponDate);
      _coupons.push();
    }
  }

  /**
   * @notice Function to run on each transfer, mint, burn and mature (action that changes the holders) to update the coupons
   *         with the holders at that time. It does not matter if there is no movement, because then it will be the current
   *         holder list.
   */
  function updateCoupons() public {
    for (uint256 i = 0; i < _couponDates.length; i++) {
      uint256 couponDate = _couponDates[i];
      Coupon storage coupon = _coupons[i];
      if (couponDate < now && !coupon.inititated) {
        coupon.inititated = true;
        coupon.holdersAtCouponDate = tokenHolders;
        for (uint256 j = 0; j < tokenHolders.length; j++) {
          uint256 holderBalance = balances[tokenHolders[j]].balance;
          uint256 couponAmount = holderBalance.div(uint256(10)**parDecimals).mul(
            _couponAmountPerBondPerSixMonths.mul(_numSixMonthsPerCoupon)
          );
          coupon.totalCouponAmount = coupon.totalCouponAmount.add(couponAmount);
          coupon.amountsAtCouponDate.push(couponAmount);
        }
      }
    }
  }

  /**
   * @notice Redeems the coupons for the supplied holder that have not been redeemed yet and have vested.
   * @dev Note that this will fail when the contract has not enough currency balance to pay out the entire un-redeemed
   *      balance of the coupon.
   * @param holder The address of the account to redeem all unredeemed and vested coupons for.
   */
  function redeemCoupons(address holder) public {
    updateCoupons();
    for (uint256 i = 0; i < _couponDates.length; i++) {
      uint256 couponDate = _couponDates[i];
      if (couponDate < now) {
        Coupon storage coupon = _coupons[i];
        uint256 totalCouponAmount = coupon.totalCouponAmount;
        require(
          _parCurrency.balanceOf(address(this)) >= totalCouponAmount.sub(coupon.redeemedCouponAmount),
          'There are not enough funds in the currency assigned to this bond to pay out coupons'
        );
        for (uint256 j = 0; j < coupon.holdersAtCouponDate.length; j++) {
          if (coupon.holdersAtCouponDate[j] == holder) {
            uint256 couponAmount = coupon.amountsAtCouponDate[j];
            require(couponAmount > 0, 'No coupon value to redeem');
            coupon.redeemedCouponAmount = coupon.redeemedCouponAmount.add(couponAmount);
            coupon.amountsAtCouponDate[j] = 0;
            require(_parCurrency.transfer(holder, couponAmount), 'Transfer of the par currency to the holder failed');
          }
        }
      }
    }
  }

  /**
   * @notice Returns the principal amount to the holder and burns the bond tokens
   * @dev Note that this will fail when the contract has not enough currency balance to pay out the entire un-claimed
   *      principal balance.
   * @param holder The address of the account to send  the principal amount to.
   */
  function claimPar(address holder) public {
    updateCoupons();
    require(_maturityDate >= now, 'The par value can only be claimed after the maturity date has passed');
    require(
      _parCurrency.balanceOf(address(this)) >= totalSupply.mul(_parValue.div(10**parDecimals)),
      'There are not enough funds in the currency assigned to this bond to pay out all par values'
    );
    redeemCoupons(holder);
    require(
      _parCurrency.transfer(holder, balanceOf(holder).mul(_parValue.div(10**parDecimals))),
      'Transfer of the par currency to the holder failed'
    );
    require(burn(holder, balanceOf(holder)), 'Burning the bond tokens failed');
  }

  function coupons() public view returns (Coupon[] memory) {
    return _coupons;
  }

  function couponDates() public view returns (uint256[] memory) {
    return _couponDates;
  }

  function mint(address to, uint256 amount) public override returns (bool success) {
    updateCoupons();
    return super.mint(to, amount);
  }

  function burn(address from, uint256 amount) public override returns (bool success) {
    updateCoupons();
    return super.burn(from, amount);
  }

  function transfer(address to, uint256 value) public virtual override returns (bool success) {
    updateCoupons();
    return super.transfer(to, value);
  }

  // function to calculate how much money needs to be there
  // override transfer, mint and burn

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
