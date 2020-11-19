import {
  createPermission,
  getNewAddressFromEvents,
  grantPermission,
  testEvent,
  testRevert,
} from '@settlemint/enteth-migration-utils';
import faker from 'faker';
import Web3 from 'web3';

import { GateKeeperContract, GateKeeperInstance } from '../types/truffle-contracts/GateKeeper';
import { ShareContract, ShareInstance } from '../types/truffle-contracts/Share';
import { ShareFactoryContract, ShareFactoryInstance } from '../types/truffle-contracts/ShareFactory';
import { ShareRegistryContract, ShareRegistryInstance } from '../types/truffle-contracts/ShareRegistry';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { storeIpfsHash } = require('../truffle-config.js'); // one dirs up, because it is compiled into ./dist/migrations

const Share: ShareContract = artifacts.require('Share');
const ShareFactory: ShareFactoryContract = artifacts.require('ShareFactory');
const ShareRegistry: ShareRegistryContract = artifacts.require('ShareRegistry');
const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');

const DECIMALS = 4;
const ZERO = Web3.utils.toBN(0);
const TWO = Web3.utils.toBN(10 ** DECIMALS * 2);
const THREE = Web3.utils.toBN(10 ** DECIMALS * 3);
const FIVE = Web3.utils.toBN(10 ** DECIMALS * 5);
const UINTMAX = Web3.utils.toBN(2).pow(Web3.utils.toBN(256)).sub(Web3.utils.toBN(1));

contract('Share', (accounts) => {
  let gateKeeper: GateKeeperInstance;
  let currency: ShareInstance;
  let currencyFactory: ShareFactoryInstance;
  let currencyRegistry: ShareRegistryInstance;

  async function verifyApproval(tx: Truffle.TransactionResponse, from: string, to: string, amount: BN) {
    const allowance = await currency.allowance(accounts[0], accounts[1]);
    assert(allowance.eq(amount), `Allowance of ${allowance.toString()} should be ${amount.toString()}`);
    testEvent(tx, 'Approval', {
      owner: from,
      spender: to,
      value: amount.toString(),
    });
  }

  before(async function () {
    gateKeeper = await GateKeeper.new();
    currencyRegistry = await ShareRegistry.new(gateKeeper.address);
    await createPermission(gateKeeper, currencyRegistry, 'LIST_TOKEN_ROLE', accounts[0], accounts[0]);
    currencyFactory = await ShareFactory.new(currencyRegistry.address, gateKeeper.address);
    await createPermission(gateKeeper, currencyFactory, 'CREATE_TOKEN_ROLE', accounts[0], accounts[0]);
    await grantPermission(gateKeeper, currencyRegistry, 'LIST_TOKEN_ROLE', currencyFactory.address);
    await grantPermission(gateKeeper, gateKeeper, 'CREATE_PERMISSIONS_ROLE', currencyFactory.address);
    await createPermission(gateKeeper, currencyFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const hash = await storeIpfsHash(require('../contracts/share/UIDefinitions.json'));
    await currencyFactory.setUIFieldDefinitionsHash(hash);
    const tx = await currencyFactory.createToken(faker.finance.currencyName(), DECIMALS);
    const currencyAddress = getNewAddressFromEvents(tx, 'TokenCreated');
    // tslint:disable-next-line: no-any
    currency = await ((Share.at(currencyAddress) as any) as Promise<ShareInstance>);
  });

  describe('totalSupply()', () => {
    it('should have initial supply of 0', async () => {
      const totalSupply = await currency.totalSupply();
      assert(totalSupply.eq(ZERO));
    });
  });

  describe('balanceOf(owner)', () => {
    it('should have correct initial balances', async () => {
      const balance = await currency.balanceOf(accounts[0]);
      assert(balance.eq(ZERO));
    });
  });

  describe('allowance(owner, spender)', () => {
    it('should have correct initial allowance', async () => {
      const allowance = await currency.allowance(accounts[0], accounts[1]);
      assert(allowance.eq(ZERO));
    });

    it('should return the correct allowance', async () => {
      const tx = await currency.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });
  });

  describe('approve(spender, value)', () => {
    it('should return true when approving 0', async () => {
      assert.isTrue(await currency.approve.call(accounts[1], ZERO, { from: accounts[0] }));
      const tx = await currency.approve(accounts[1], ZERO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], ZERO);
    });

    it('should return true when approving', async () => {
      assert.isTrue(await currency.approve.call(accounts[1], THREE, { from: accounts[0] }));
      const tx = await currency.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });

    it('should return true when updating approval to the same', async () => {
      assert.isTrue(await currency.approve.call(accounts[1], THREE, { from: accounts[0] }));
      const tx = await currency.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });

    it('should return true when updating approval to less', async () => {
      assert.isTrue(await currency.approve.call(accounts[1], TWO, { from: accounts[0] }));
      const tx = await currency.approve(accounts[1], TWO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], TWO);
    });

    it('should return true when updating approval to more', async () => {
      assert.isTrue(await currency.approve.call(accounts[1], FIVE, { from: accounts[0] }));
      const tx = await currency.approve(accounts[1], FIVE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], FIVE);
    });

    it('should return true when updating approval to 0', async () => {
      assert.isTrue(await currency.approve.call(accounts[1], ZERO, { from: accounts[0] }));
      const tx = await currency.approve(accounts[1], ZERO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], ZERO);
    });

    it('should fire Approval event', async () => {
      const tx = await currency.approve(accounts[1], FIVE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], FIVE);
    });

    it('should fire Approval when allowance was set to 0', async () => {
      const tx = await currency.approve(accounts[1], ZERO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], ZERO);
    });

    it('should fire Approval even when allowance did not change', async () => {
      let tx = await currency.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
      tx = await currency.approve(accounts[1], THREE, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });
  });

  describe('increaseApproval(spender, value)', () => {
    it('should return true when increasing approval', async () => {
      await currency.approve(accounts[1], THREE, { from: accounts[0] });
      assert.isTrue(await currency.increaseApproval.call(accounts[1], TWO, { from: accounts[0] }));
      const tx = await currency.increaseApproval(accounts[1], TWO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], FIVE);
    });

    it('should revert when approval cannot be increased', async function () {
      await currency.approve(accounts[1], FIVE, { from: accounts[0] });
      await testRevert(
        currency.increaseApproval(accounts[1], UINTMAX, { from: accounts[0] }),
        'VM Exception while processing transaction: revert SafeMath: addition overflow'
      );
    });
  });

  describe('decreaseApproval(spender, value)', () => {
    it('should return true when decreasing approval', async () => {
      await currency.approve(accounts[1], FIVE, { from: accounts[0] });
      assert.isTrue(await currency.decreaseApproval.call(accounts[1], TWO, { from: accounts[0] }));
      const tx = await currency.decreaseApproval(accounts[1], TWO, { from: accounts[0] });
      await verifyApproval(tx, accounts[0], accounts[1], THREE);
    });
  });

  describe('getUIFieldDefinitionsHash()', () => {
    it('the factory has UI definitions', async () => {
      const uiFieldDefinitionsHash = await currencyFactory.getUIFieldDefinitionsHash();
      assert.isNotNull(uiFieldDefinitionsHash);
    });
    it('the currency has the same UI definitions', async () => {
      const factoryUiFieldDefinitionsHash = await currencyFactory.getUIFieldDefinitionsHash();
      const uiFieldDefinitionsHash = await currency._uiFieldDefinitionsHash();
      assert.equal(uiFieldDefinitionsHash, factoryUiFieldDefinitionsHash);
    });
  });

  describe('mint(address _to, uint256 _amount)', () => {
    it('mint new tokens', async () => {
      const balanceBefore = await currency.balanceOf(accounts[1]);
      assert.equal(balanceBefore.toNumber(), 0);
      const tx = await currency.mint(accounts[1], FIVE);
      testEvent(tx, 'Mint', { to: accounts[1], amount: FIVE.toString() });
      testEvent(tx, 'Transfer', {
        from: '0x0000000000000000000000000000000000000000',
        to: accounts[1],
        value: FIVE.toString(),
      });
      const balanceAfter = await currency.balanceOf(accounts[1]);
      assert.equal(balanceAfter.toNumber(), FIVE.toNumber());
    });
  });

  describe('burn(address _from, uint256 _amount)', () => {
    it('burn tokens', async () => {
      await currency.mint(accounts[2], FIVE);
      const balanceBefore = await currency.balanceOf(accounts[2]);
      assert.equal(balanceBefore.toNumber(), FIVE.toNumber());
      const tx = await currency.burn(accounts[2], TWO);
      testEvent(tx, 'Burn', { from: accounts[2], amount: TWO.toString() });
      testEvent(tx, 'Transfer', {
        from: accounts[2],
        to: '0x0000000000000000000000000000000000000000',
        value: TWO.toString(),
      });
      const balanceAfter = await currency.balanceOf(accounts[2]);
      assert.equal(balanceAfter.toNumber(), THREE.toNumber());
    });
  });

  describe('transfer(address _to, uint256 _value)', () => {
    it('transfer tokens', async () => {
      await currency.mint(accounts[3], FIVE);
      const balanceBefore = await currency.balanceOf(accounts[3]);
      assert.equal(balanceBefore.toNumber(), FIVE.toNumber());
      const tx = await currency.transfer(accounts[4], TWO, { from: accounts[3] });
      testEvent(tx, 'Transfer', {
        from: accounts[3],
        to: accounts[4],
        value: TWO.toString(),
      });
      const balanceAfterFrom = await currency.balanceOf(accounts[3]);
      assert.equal(balanceAfterFrom.toNumber(), THREE.toNumber());
      const balanceAfterTo = await currency.balanceOf(accounts[4]);
      assert.equal(balanceAfterTo.toNumber(), TWO.toNumber());
    });
  });

  describe('transferWithData(address _to, uint256 _value, bytes _data)', () => {
    it('transfer tokens with data', async () => {
      await currency.mint(accounts[5], FIVE);
      const balanceBefore = await currency.balanceOf(accounts[5]);
      assert.equal(balanceBefore.toNumber(), FIVE.toNumber());
      const tx = await currency.transferWithData(accounts[6], THREE, Web3.utils.asciiToHex('some-payment-reference'), {
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
      const balanceAfter0 = await currency.balanceOf(accounts[5]);
      assert.equal(balanceAfter0.toNumber(), TWO.toNumber());
      const balanceAfter1 = await currency.balanceOf(accounts[6]);
      assert.equal(balanceAfter1.toNumber(), THREE.toNumber());
    });
  });

  describe('transferFrom (address _from, address _to, uint256 _value )', () => {
    it('transfer tokens from', async () => {
      await currency.mint(accounts[8], FIVE);
      const balanceBefore1 = await currency.balanceOf(accounts[8]);
      assert.equal(balanceBefore1.toNumber(), FIVE.toNumber());
      const balanceBefore2 = await currency.balanceOf(accounts[7]);
      assert.equal(balanceBefore2.toNumber(), ZERO.toNumber());
      await currency.approve(accounts[0], FIVE, { from: accounts[8] });
      const tx = await currency.transferFrom(accounts[8], accounts[7], THREE);
      testEvent(tx, 'Transfer', {
        from: accounts[8],
        to: accounts[7],
        value: THREE.toString(),
      });
      const balanceAfter0 = await currency.balanceOf(accounts[8]);
      assert.equal(balanceAfter0.toNumber(), TWO.toNumber());
      const balanceAfter1 = await currency.balanceOf(accounts[7]);
      assert.equal(balanceAfter1.toNumber(), THREE.toNumber());
    });
  });

  describe('transferFromWithData(address _from,address _to,uint256 _value,bytes _data)', () => {
    it('transfer tokens from with data', async () => {
      await currency.mint(accounts[8], THREE); // TWO from previous test
      const balanceBefore1 = await currency.balanceOf(accounts[8]);
      assert.equal(balanceBefore1.toNumber(), FIVE.toNumber());
      const balanceBefore2 = await currency.balanceOf(accounts[9]);
      assert.equal(balanceBefore2.toNumber(), ZERO.toNumber());
      await currency.approve(accounts[0], THREE, { from: accounts[8] });
      const tx = await currency.transferFromWithData(
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
      const balanceAfter0 = await currency.balanceOf(accounts[8]);
      assert.equal(balanceAfter0.toNumber(), TWO.toNumber());
      const balanceAfter1 = await currency.balanceOf(accounts[9]);
      assert.equal(balanceAfter1.toNumber(), THREE.toNumber());
    });
  });
});
