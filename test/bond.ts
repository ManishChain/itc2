import {
  createPermission,
  getNewAddressFromEvents,
  grantPermission,
  testEvent,
  testRevert,
  timeTravel,
} from '@settlemint/enteth-migration-utils';
import dayjs from 'dayjs';
import faker from 'faker';
import Web3 from 'web3'; // one dir up, because it is compiled into ./dist/migrations

import { BondContract, BondInstance ,BondFactoryContract, BondFactoryInstance,BondRegistryContract, BondRegistryInstance , CurrencyContract, CurrencyInstance,CurrencyFactoryContract, CurrencyFactoryInstance,CurrencyRegistryContract, CurrencyRegistryInstance, GateKeeperContract, GateKeeperInstance } from '../types/truffle-contracts';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { storeIpfsHash } = require('../truffle-config.js');

const Bond: BondContract = artifacts.require('Bond');
const BondFactory: BondFactoryContract = artifacts.require('BondFactory');
const BondRegistry: BondRegistryContract = artifacts.require('BondRegistry');
const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const Currency: CurrencyContract = artifacts.require('Currency');
const CurrencyFactory: CurrencyFactoryContract = artifacts.require('CurrencyFactory');
const CurrencyRegistry: CurrencyRegistryContract = artifacts.require('CurrencyRegistry');

const DECIMALS = 4;
const ZERO = Web3.utils.toBN(0);
const TWO = Web3.utils.toBN(10 ** DECIMALS * 2);
const THREE = Web3.utils.toBN(10 ** DECIMALS * 3);
const FIVE = Web3.utils.toBN(10 ** DECIMALS * 5);
const MILLION = Web3.utils.toBN(10 ** DECIMALS * 1000000);

const UINTMAX = Web3.utils.toBN(2).pow(Web3.utils.toBN(256)).sub(Web3.utils.toBN(1));

contract('Bond', (accounts) => {
  let gateKeeper: GateKeeperInstance;
  let bond: BondInstance;
  let bondFactory: BondFactoryInstance;
  let bondRegistry: BondRegistryInstance;
  let currency: CurrencyInstance;
  let currencyFactory: CurrencyFactoryInstance;
  let currencyRegistry: CurrencyRegistryInstance;
  let startDate: number;
  let ipfsHash: string;

  async function verifyApproval(tx: Truffle.TransactionResponse, from: string, to: string, amount: BN) {
    const allowance = await bond.allowance(accounts[0], accounts[1]);
    assert(allowance.eq(amount), `Allowance of ${allowance.toString()} should be ${amount.toString()}`);
    testEvent(tx, 'Approval', {
      owner: from,
      spender: to,
      value: amount.toString(),
    });
  }

  before(async function () {
    gateKeeper = await GateKeeper.new();
    // Currency
    currencyRegistry = await CurrencyRegistry.new(gateKeeper.address);
    await createPermission(gateKeeper, currencyRegistry, 'LIST_TOKEN_ROLE', accounts[0], accounts[0]);
    currencyFactory = await CurrencyFactory.new(currencyRegistry.address, gateKeeper.address);
    await createPermission(gateKeeper, currencyFactory, 'CREATE_TOKEN_ROLE', accounts[0], accounts[0]);
    await grantPermission(gateKeeper, currencyRegistry, 'LIST_TOKEN_ROLE', currencyFactory.address);
    await grantPermission(gateKeeper, gateKeeper, 'CREATE_PERMISSIONS_ROLE', currencyFactory.address);
    await createPermission(gateKeeper, currencyFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const currencyHash = await storeIpfsHash(require('../contracts/currency/UIDefinitions.json'));
    await currencyFactory.setUIFieldDefinitionsHash(currencyHash);
    const currencyTx = await currencyFactory.createToken(faker.finance.currencyName(), DECIMALS);
    const currencyAddress = getNewAddressFromEvents(currencyTx, 'TokenCreated');
    // tslint:disable-next-line: no-any
    currency = await ((Currency.at(currencyAddress) as any) as Promise<CurrencyInstance>);
    // Bonds
    bondRegistry = await BondRegistry.new(gateKeeper.address);
    await createPermission(gateKeeper, bondRegistry, 'LIST_TOKEN_ROLE', accounts[0], accounts[0]);
    bondFactory = await BondFactory.new(bondRegistry.address, gateKeeper.address);
    await createPermission(gateKeeper, bondFactory, 'CREATE_TOKEN_ROLE', accounts[0], accounts[0]);
    await grantPermission(gateKeeper, bondRegistry, 'LIST_TOKEN_ROLE', bondFactory.address);
    await grantPermission(gateKeeper, gateKeeper, 'CREATE_PERMISSIONS_ROLE', bondFactory.address);
    await createPermission(gateKeeper, bondFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const hash = await storeIpfsHash(require('../contracts/bonds/UIDefinitions.json'));
    await bondFactory.setUIFieldDefinitionsHash(hash);

    // go 1 day in te future
    await timeTravel(3600 * 24);

    ipfsHash = await storeIpfsHash({
      isin: faker.finance.iban(),
      issuer: faker.company.companyName(),
    });

    const tx = await bondFactory.createToken(
      faker.company.companyName(),
      10 ** DECIMALS * 1000,
      currency.address,
      24,
      10,
      6,
      DECIMALS,
      ipfsHash
    );
    const bondAddress = getNewAddressFromEvents(tx, 'TokenCreated');
    // tslint:disable-next-line: no-any
    bond = await ((Bond.at(bondAddress) as any) as Promise<BondInstance>);
  });

  describe('totalSupply()', () => {
    it('should have initial supply of 0', async () => {
      const totalSupply = await bond.totalSupply();
      assert(totalSupply.eq(ZERO));
    });
  });

  describe('balanceOf(owner)', () => {
    it('should have correct initial balances', async () => {
      const balance = await bond.balanceOf(accounts[0]);
      assert(balance.eq(ZERO));
    });
  });

  describe('allowance(owner, spender)', () => {
    it('should have correct initial allowance', async () => {
      const allowance = await bond.allowance(accounts[0], accounts[1]);
      assert(allowance.eq(ZERO));
    });

    it('should return the correct allowance', async () => {
      const tx = await bond.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });
  });

  describe('approve(spender, value)', () => {
    it('should return true when approving 0', async () => {
      assert.isTrue(await bond.approve.call(accounts[1], ZERO, { from: accounts[0] }));
      const tx = await bond.approve(accounts[1], ZERO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], ZERO);
    });

    it('should return true when approving', async () => {
      assert.isTrue(await bond.approve.call(accounts[1], THREE, { from: accounts[0] }));
      const tx = await bond.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });

    it('should return true when updating approval to the same', async () => {
      assert.isTrue(await bond.approve.call(accounts[1], THREE, { from: accounts[0] }));
      const tx = await bond.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });

    it('should return true when updating approval to less', async () => {
      assert.isTrue(await bond.approve.call(accounts[1], TWO, { from: accounts[0] }));
      const tx = await bond.approve(accounts[1], TWO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], TWO);
    });

    it('should return true when updating approval to more', async () => {
      assert.isTrue(await bond.approve.call(accounts[1], FIVE, { from: accounts[0] }));
      const tx = await bond.approve(accounts[1], FIVE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], FIVE);
    });

    it('should return true when updating approval to 0', async () => {
      assert.isTrue(await bond.approve.call(accounts[1], ZERO, { from: accounts[0] }));
      const tx = await bond.approve(accounts[1], ZERO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], ZERO);
    });

    it('should fire Approval event', async () => {
      const tx = await bond.approve(accounts[1], FIVE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], FIVE);
    });

    it('should fire Approval when allowance was set to 0', async () => {
      const tx = await bond.approve(accounts[1], ZERO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], ZERO);
    });

    it('should fire Approval even when allowance did not change', async () => {
      let tx = await bond.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
      tx = await bond.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });
  });

  describe('increaseApproval(spender, value)', () => {
    it('should return true when increasing approval', async () => {
      await bond.approve(accounts[1], THREE, { from: accounts[0] });
      assert.isTrue(await bond.increaseApproval.call(accounts[1], TWO, { from: accounts[0] }));
      const tx = await bond.increaseApproval(accounts[1], TWO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], FIVE);
    });

    it('should revert when approval cannot be increased', async function () {
      await bond.approve(accounts[1], FIVE, { from: accounts[0] });
      await testRevert(bond.increaseApproval(accounts[1], UINTMAX, { from: accounts[0] }));
    });
  });

  describe('decreaseApproval(spender, value)', () => {
    it('should return true when decreasing approval', async () => {
      await bond.approve(accounts[1], FIVE, { from: accounts[0] });
      assert.isTrue(await bond.decreaseApproval.call(accounts[1], TWO, { from: accounts[0] }));
      const tx = await bond.decreaseApproval(accounts[1], TWO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });
  });

  describe('getUIFieldDefinitionsHash()', () => {
    it('the factory has UI definitions', async () => {
      const uiFieldDefinitionsHash = await bondFactory.getUIFieldDefinitionsHash();
      assert.isNotNull(uiFieldDefinitionsHash);
    });
    it('the bond has the same UI definitions', async () => {
      const factoryUiFieldDefinitionsHash = await bondFactory.getUIFieldDefinitionsHash();
      const uiFieldDefinitionsHash = await bond._uiFieldDefinitionsHash();
      assert.equal(uiFieldDefinitionsHash, factoryUiFieldDefinitionsHash);
    });
  });

  describe('mint(address _to, uint256 _amount)', () => {
    it('mint new tokens', async () => {
      const balanceBefore = await bond.balanceOf(accounts[1]);
      assert.equal(balanceBefore.toNumber(), 0);
      const tx = await bond.mint(accounts[1], FIVE);
      testEvent(tx, 'Mint', { to: accounts[1], amount: FIVE.toString() });
      testEvent(tx, 'Transfer', {
        from: '0x0000000000000000000000000000000000000000',
        to: accounts[1],
        value: FIVE.toString(),
      });
      const balanceAfter = await bond.balanceOf(accounts[1]);
      assert.equal(balanceAfter.toNumber(), FIVE.toNumber());
    });
  });

  describe('burn(address _from, uint256 _amount)', () => {
    it('burn tokens', async () => {
      await bond.mint(accounts[2], FIVE);
      const balanceBefore = await bond.balanceOf(accounts[2]);
      assert.equal(balanceBefore.toNumber(), FIVE.toNumber());
      const tx = await bond.burn(accounts[2], TWO);
      testEvent(tx, 'Burn', { from: accounts[2], amount: TWO.toString() });
      testEvent(tx, 'Transfer', {
        from: accounts[2],
        to: '0x0000000000000000000000000000000000000000',
        value: TWO.toString(),
      });
      const balanceAfter = await bond.balanceOf(accounts[2]);
      assert.equal(balanceAfter.toNumber(), THREE.toNumber());
    });
  });

  describe('transfer(address _to, uint256 _value)', () => {
    it('transfer tokens', async () => {
      await bond.mint(accounts[3], FIVE);
      const balanceBefore = await bond.balanceOf(accounts[3]);
      assert.equal(balanceBefore.toNumber(), FIVE.toNumber());
      const tx = await bond.transfer(accounts[4], TWO, { from: accounts[3] });
      testEvent(tx, 'Transfer', {
        from: accounts[3],
        to: accounts[4],
        value: TWO.toString(),
      });
      const balanceAfterFrom = await bond.balanceOf(accounts[3]);
      assert.equal(balanceAfterFrom.toNumber(), THREE.toNumber());
      const balanceAfterTo = await bond.balanceOf(accounts[4]);
      assert.equal(balanceAfterTo.toNumber(), TWO.toNumber());
    });
  });

  describe('transferWithData(address _to, uint256 _value, bytes _data)', () => {
    it('transfer tokens with data', async () => {
      await bond.mint(accounts[5], FIVE);
      const balanceBefore = await bond.balanceOf(accounts[5]);
      assert.equal(balanceBefore.toNumber(), FIVE.toNumber());
      const tx = await bond.transferWithData(accounts[6], THREE, Web3.utils.asciiToHex('some-payment-reference'), {
        from: accounts[5],
      });
      testEvent(tx, 'Transfer', {
        from: accounts[5],
        to: accounts[6],
        value: THREE.toString(),
      });
      testEvent(tx, 'TransferData', {
        from: accounts[5],
        to: accounts[6],
        data: Web3.utils.asciiToHex('some-payment-reference'),
      });
      const balanceAfter0 = await bond.balanceOf(accounts[5]);
      assert.equal(balanceAfter0.toNumber(), TWO.toNumber());
      const balanceAfter1 = await bond.balanceOf(accounts[6]);
      assert.equal(balanceAfter1.toNumber(), THREE.toNumber());
    });
  });

  describe('transferFrom (address _from, address _to, uint256 _value )', () => {
    it('transfer tokens from', async () => {
      await bond.mint(accounts[8], FIVE);
      const balanceBefore1 = await bond.balanceOf(accounts[8]);
      assert.equal(balanceBefore1.toNumber(), FIVE.toNumber());
      const balanceBefore2 = await bond.balanceOf(accounts[7]);
      assert.equal(balanceBefore2.toNumber(), ZERO.toNumber());
      await bond.approve(accounts[0], FIVE, { from: accounts[8] });
      const tx = await bond.transferFrom(accounts[8], accounts[7], THREE);
      testEvent(tx, 'Transfer', {
        from: accounts[8],
        to: accounts[7],
        value: THREE.toString(),
      });
      const balanceAfter0 = await bond.balanceOf(accounts[8]);
      assert.equal(balanceAfter0.toNumber(), TWO.toNumber());
      const balanceAfter1 = await bond.balanceOf(accounts[7]);
      assert.equal(balanceAfter1.toNumber(), THREE.toNumber());
    });
  });

  describe('transferFromWithData(address _from,address _to,uint256 _value,bytes _data)', () => {
    it('transfer tokens from with data', async () => {
      await bond.mint(accounts[8], THREE); // TWO from previous test
      const balanceBefore1 = await bond.balanceOf(accounts[8]);
      assert.equal(balanceBefore1.toNumber(), FIVE.toNumber());
      const balanceBefore2 = await bond.balanceOf(accounts[9]);
      assert.equal(balanceBefore2.toNumber(), ZERO.toNumber());
      await bond.approve(accounts[0], THREE, { from: accounts[8] });
      const tx = await bond.transferFromWithData(
        accounts[8],
        accounts[9],
        THREE,
        Web3.utils.asciiToHex('some-payment-reference')
      );
      testEvent(tx, 'Transfer', {
        from: accounts[8],
        to: accounts[9],
        value: THREE.toString(),
      });
      testEvent(tx, 'TransferData', {
        from: accounts[8],
        to: accounts[9],
        data: Web3.utils.asciiToHex('some-payment-reference'),
      });
      const balanceAfter0 = await bond.balanceOf(accounts[8]);
      assert.equal(balanceAfter0.toNumber(), TWO.toNumber());
      const balanceAfter1 = await bond.balanceOf(accounts[9]);
      assert.equal(balanceAfter1.toNumber(), THREE.toNumber());
    });
  });

  describe('edit(string memory name,uint256 parValue,Currency parCurrency,uint256 maturityPeriod,uint256 couponRate,uint256 couponPeriod,uint8 decimals,string memory ipfsFieldContainerHash)', () => {
    it('can edit the offchain data of a bond', async () => {
      await bond.edit(await bond._name(), 10 ** DECIMALS * 1000, currency.address, 24, 10, 6, DECIMALS, ipfsHash);
    });
    it('can edit the onchain data of a bond', async () => {
      await bond.edit(
        faker.company.companyName(),
        10 ** DECIMALS * 2000,
        currency.address,
        24,
        10,
        6,
        DECIMALS,
        await bond.getIpfsFieldContainerHash()
      );
    });
    it('can edit the both the onchain and offchain data of a bond', async () => {
      await bond.edit(
        faker.company.companyName(),
        10 ** DECIMALS * 3000,
        currency.address,
        24,
        10,
        6,
        DECIMALS,
        ipfsHash
      );
    });
    it('can no longer edit after the launch period is set', async () => {
      await bond.edit(
        faker.company.companyName(),
        10 ** DECIMALS * 3000,
        currency.address,
        24,
        10,
        6,
        DECIMALS,
        ipfsHash
      );
      startDate = dayjs().add(10, 'day').unix();
      await bond.setIssuanceDate(startDate);
      await bond.edit(
        faker.company.companyName(),
        10 ** DECIMALS * 3000,
        currency.address,
        24,
        10,
        6,
        DECIMALS,
        ipfsHash
      );
      await bond.launch(startDate);
      await timeTravel(3600 * 24 * 12);
      await testRevert(
        bond.edit(faker.company.companyName(), 10 ** DECIMALS * 3000, currency.address, 24, 10, 6, DECIMALS, ipfsHash)
      );
    });
  });

  const couponFixture = [
    [
      true,
      '390000',
      '0',
      [
        '0x4A15DeD528F963c9408ceb8e19f9f97Bcf5D31D2',
        '0x745A6Bd46c2Ec788Cb044b7d9e61aE1063aA2B57',
        '0x4Bd0ed5458a63D7ab7A73b39E73b09b43BF8f3FA',
        '0xfE86238Ed27Fd807c994c2850feD037C91fCb2D2',
        '0x0dE74DAbB8ad4886055b432043360216bcb01f48',
        '0xA7dC926D3526C46d3A1B254Ca932D293a8c8bAb8',
        '0x799213f3b7ADAF228792f5FfD3aDEf3302209F36',
        '0x666e84ce97379Ae34fdC6B0D15A3e0B1e4c31b24',
        '0xbf4ce2704d662007bB37b434A33eC6ff7087b526',
      ],
      ['75000', '45000', '45000', '30000', '30000', '45000', '30000', '45000', '45000'],
    ],
    [
      true,
      '390000',
      '0',
      [
        '0x4A15DeD528F963c9408ceb8e19f9f97Bcf5D31D2',
        '0x745A6Bd46c2Ec788Cb044b7d9e61aE1063aA2B57',
        '0x4Bd0ed5458a63D7ab7A73b39E73b09b43BF8f3FA',
        '0xfE86238Ed27Fd807c994c2850feD037C91fCb2D2',
        '0x0dE74DAbB8ad4886055b432043360216bcb01f48',
        '0xA7dC926D3526C46d3A1B254Ca932D293a8c8bAb8',
        '0x799213f3b7ADAF228792f5FfD3aDEf3302209F36',
        '0x666e84ce97379Ae34fdC6B0D15A3e0B1e4c31b24',
        '0xbf4ce2704d662007bB37b434A33eC6ff7087b526',
      ],
      ['75000', '45000', '45000', '30000', '30000', '45000', '30000', '45000', '45000'],
    ],
    [false, '0', '0', [], []],
    [false, '0', '0', [], []],
  ];

  describe('getCoupons()', () => {
    it('can get a list of all the balances', async () => {
      const length = await bond.getIndexLength();
      const balances: string[] = [];
      for (let i = 0; i < length.toNumber(); i++) {
        const balance = await bond.getByIndex(i);
        balances.push(`${balance[0]} - ${balance[1].toString()}`);
      }
      expect(balances).to.deep.equal([
        '0x4A15DeD528F963c9408ceb8e19f9f97Bcf5D31D2 - 50000',
        '0x745A6Bd46c2Ec788Cb044b7d9e61aE1063aA2B57 - 30000',
        '0x4Bd0ed5458a63D7ab7A73b39E73b09b43BF8f3FA - 30000',
        '0xfE86238Ed27Fd807c994c2850feD037C91fCb2D2 - 20000',
        '0x0dE74DAbB8ad4886055b432043360216bcb01f48 - 20000',
        '0xA7dC926D3526C46d3A1B254Ca932D293a8c8bAb8 - 30000',
        '0x799213f3b7ADAF228792f5FfD3aDEf3302209F36 - 20000',
        '0x666e84ce97379Ae34fdC6B0D15A3e0B1e4c31b24 - 30000',
        '0xbf4ce2704d662007bB37b434A33eC6ff7087b526 - 30000',
      ]);
    });

    it('can get a list of all the coupons', async () => {
      const coupons = await bond.coupons();
      expect(coupons).to.deep.equal([
        [false, '0', '0', [], []],
        [false, '0', '0', [], []],
        [false, '0', '0', [], []],
        [false, '0', '0', [], []],
      ]);
    });

    it('can get a list of all the coupon days', async () => {
      const couponDates = await bond.couponDates();
      expect(couponDates.map((cd) => cd.toNumber())).to.deep.equal([
        startDate + 6 * 4 * 7 * 24 * 3600,
        startDate + 12 * 4 * 7 * 24 * 3600,
        startDate + 18 * 4 * 7 * 24 * 3600,
        startDate + 24 * 4 * 7 * 24 * 3600,
      ]);
    });

    it('can get a list of some activated coupons', async () => {
      await timeTravel(3600 * 24 * 7 * 52);
      await bond.updateCoupons();
      const coupons = await bond.coupons();

      expect(coupons).to.deep.equal(couponFixture);
    });
  });

  describe('redeemCoupons(address)', () => {
    it('can redeem coupons', async () => {
      await currency.mint(bond.address, MILLION);
      await bond.redeemCoupons(accounts[1]);
      const coupons = await bond.coupons();
      couponFixture[0][2] = '75000';
      couponFixture[0][4][0] = '0';
      couponFixture[1][2] = '75000';
      couponFixture[1][4][0] = '0';
      expect(coupons).to.deep.equal(couponFixture);
    });
  });

  describe('claimPar(address)', () => {
    it('can claim the par back', async () => {
      await currency.mint(bond.address, MILLION);
      await bond.claimPar(accounts[2]);
      const coupons = await bond.coupons();
      couponFixture[0][2] = '120000';
      couponFixture[0][4][1] = '0';
      couponFixture[1][2] = '120000';
      couponFixture[1][4][1] = '0';
      expect(coupons).to.deep.equal(couponFixture);
      const length = await bond.getIndexLength();
      const balances: string[] = [];
      for (let i = 0; i < length.toNumber(); i++) {
        const balance = await bond.getByIndex(i);
        balances.push(`${balance[0]} - ${balance[1].toString()}`);
      }
      expect(balances).to.deep.equal([
        '0x4A15DeD528F963c9408ceb8e19f9f97Bcf5D31D2 - 50000',
        '0x745A6Bd46c2Ec788Cb044b7d9e61aE1063aA2B57 - 0',
        '0x4Bd0ed5458a63D7ab7A73b39E73b09b43BF8f3FA - 30000',
        '0xfE86238Ed27Fd807c994c2850feD037C91fCb2D2 - 20000',
        '0x0dE74DAbB8ad4886055b432043360216bcb01f48 - 20000',
        '0xA7dC926D3526C46d3A1B254Ca932D293a8c8bAb8 - 30000',
        '0x799213f3b7ADAF228792f5FfD3aDEf3302209F36 - 20000',
        '0x666e84ce97379Ae34fdC6B0D15A3e0B1e4c31b24 - 30000',
        '0xbf4ce2704d662007bB37b434A33eC6ff7087b526 - 30000',
      ]);
    });
  });
});
