import { StatefulOmnibusBondInstance } from '../types/truffle-contracts/StatefulOmnibusBond';
import { BondManagerContract, BondManagerInstance } from '../types/truffle-contracts/BondManager';
import {
  GateKeeperInstance,
  GateKeeperContract,
  StatefulOmnibusBondRegistryInstance,
  StatefulOmnibusBondContract,
  StatefulOmnibusBondRegistryContract,
  StatefulOmnibusBondFactoryContract,
  StatefulOmnibusBondFactoryInstance,
  AdminRoleRegistryContract,
  MakerRoleRegistryContract,
  CheckerRoleRegistryContract,
  AdminRoleRegistryInstance,
  CheckerRoleRegistryInstance,
  MakerRoleRegistryInstance,
  BondManagerRegistryContract,
  BondManagerRegistryInstance,
  BondManagerFactoryContract,
  BondManagerFactoryInstance,
} from 'types/truffle-contracts';
import { createPermission, grantPermission } from '@settlemint/enteth-migration-utils';
import faker from 'faker';
import dayjs from 'dayjs';
import web3 from 'web3';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { storeIpfsHash } = require('../truffle-config.js'); // one dir up, because it is compiled into ./dist/migrations

// eslint-disable-next-line @typescript-eslint/no-var-requires
const UIDefinitionsBondManager = require('../contracts/statefulomnibusbonds/UIDefinitionsBondManager.json');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const UIDefinitionsSOB = require('../contracts/statefulomnibusbonds/UIDefinitionsSOB.json');

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const StatefulOmnibusBondRegistry: StatefulOmnibusBondRegistryContract = artifacts.require(
  'StatefulOmnibusBondRegistry'
);
const StatefulOmnibusBond: StatefulOmnibusBondContract = artifacts.require('StatefulOmnibusBond');
const StatefulOmnibusBondFactory: StatefulOmnibusBondFactoryContract = artifacts.require('StatefulOmnibusBondFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const MakerRoleRegistry: MakerRoleRegistryContract = artifacts.require('MakerRoleRegistry');
const CheckerRoleRegistry: CheckerRoleRegistryContract = artifacts.require('CheckerRoleRegistry');
const BondManager: BondManagerContract = artifacts.require('BondManager');
const BondManagerRegistry: BondManagerRegistryContract = artifacts.require('BondManagerRegistry');
const BondManagerFactory: BondManagerFactoryContract = artifacts.require('BondManagerFactory');

contract('StatefulOmnibusBond and BondManager', (accounts: string[]) => {
  let gateKeeper: GateKeeperInstance;
  let statefulOmnibusBond: StatefulOmnibusBondInstance;
  let statefulOmnibusBondRegistry: StatefulOmnibusBondRegistryInstance;
  let statefulOmnibusBondFactory: StatefulOmnibusBondFactoryInstance;
  let bondManagerFactory: BondManagerFactoryInstance;
  let admin: AdminRoleRegistryInstance;
  let checker: CheckerRoleRegistryInstance;
  let maker: MakerRoleRegistryInstance;
  let roles: any[];

  const interest = faker.random.number(15) + 1;
  const issuanceDate = dayjs();
  const duration = 1 * 12;
  const maturityDate = issuanceDate.add(duration, 'month');
  const periodString = 'ANN'; // 'SEMI';
  const parValue = 1 * 1000;

  const statefulOmnibusBondProperties = {
    name: `BOND ${interest}% ${maturityDate.format('YY-MM-DD')} ${periodString}`,
    symbol: `BONDY`,
    isin: faker.finance.iban(),
    frequency: web3.utils.fromUtf8(periodString),
    interest,
    decimals: 3,
    issuer: faker.company.companyName(),
    maturityDate: maturityDate.unix(),
    issuanceDate: issuanceDate.unix(),
    currency: 'Singapore Dollar',
    parValue,
    couponRate: Math.floor((interest / 100) * parValue),
  };

  let ipfsHash: string;

  // Setting up bond manager variables for testing
  let bondManager: BondManagerInstance;
  let bondManagerRegistry: BondManagerRegistryInstance;

  const accountWM = 'WealthManagement';
  const account2 = faker.finance.iban();

  const burnRequestComment1 = `Burn 500 tokens for account ${accountWM}`;
  const burnRequestComment2 = `Burn 300 tokens for account ${accountWM}`;
  const burnApproveComment = `Burning of 500 tokens for ${accountWM} is approved`;
  const burnDenyComment = `Burning of 300 tokens for ${accountWM} is denied`;

  const mintRequestComment1 = `Mint 500 tokens for account ${accountWM}`;
  const mintRequestComment2 = `Mint 300 tokens for account ${accountWM}`;
  const mintApproveComment = `Minting of 500 tokens for ${accountWM} is approved`;
  const mintDenyComment = `Minting of 300 tokens for ${accountWM} is denied`;

  before(async function () {
    // Deploy gateKeeper contract
    gateKeeper = await GateKeeper.new();

    // Deploy role registry contracts
    admin = await AdminRoleRegistry.new(gateKeeper.address);
    checker = await CheckerRoleRegistry.new(gateKeeper.address);
    maker = await MakerRoleRegistry.new(gateKeeper.address);
    roles = [admin, checker, maker];

    // Give the 'DESIGNATE_ROLE' to accounts[0] for the three role registries
    // This allows accounts[0] to designate these roles to other accounts (and itself) since its msg.sender
    await createPermission(gateKeeper, admin, 'DESIGNATE_ROLE', accounts[0], accounts[0]);
    await createPermission(gateKeeper, maker, 'DESIGNATE_ROLE', accounts[0], accounts[0]);
    await createPermission(gateKeeper, checker, 'DESIGNATE_ROLE', accounts[0], accounts[0]);

    // designate the ADMIN_ROLE to accounts[0]
    await admin.designate(accounts[0]);

    // deploy a new statefulbond registry contract
    statefulOmnibusBondRegistry = await StatefulOmnibusBondRegistry.new(gateKeeper.address);
    bondManagerRegistry = await BondManagerRegistry.new(gateKeeper.address);

    // The INSERT_STATEMACHINE_ROLE permission allows accounts[0]
    // to add a statemachine instance to the statemachine registry
    // In this case it means adding the statefulbond contract to the statefulbond registry
    await createPermission(
      gateKeeper,
      statefulOmnibusBondRegistry,
      'INSERT_STATEMACHINE_ROLE',
      accounts[0],
      accounts[0]
    );

    await createPermission(gateKeeper, bondManagerRegistry, 'INSERT_STATEMACHINE_ROLE', accounts[0], accounts[0]);

    bondManagerFactory = await BondManagerFactory.new(gateKeeper.address, bondManagerRegistry.address);

    await createPermission(gateKeeper, bondManagerFactory, 'CREATE_STATEMACHINE_ROLE', accounts[0], accounts[0]);
    await createPermission(gateKeeper, bondManagerFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);

    statefulOmnibusBondFactory = await StatefulOmnibusBondFactory.new(
      gateKeeper.address,
      statefulOmnibusBondRegistry.address,
      bondManagerFactory.address
    );

    await createPermission(
      gateKeeper,
      statefulOmnibusBondFactory,
      'CREATE_STATEMACHINE_ROLE',
      accounts[0],
      accounts[0]
    );
    await createPermission(
      gateKeeper,
      statefulOmnibusBondFactory,
      'UPDATE_UIFIELDDEFINITIONS_ROLE',
      accounts[0],
      accounts[0]
    );

    for (const role of roles) {
      await grantPermission(gateKeeper, bondManagerFactory, 'CREATE_STATEMACHINE_ROLE', role.address);
      await grantPermission(gateKeeper, statefulOmnibusBondFactory, 'CREATE_STATEMACHINE_ROLE', role.address);
    }

    await grantPermission(
      gateKeeper,
      statefulOmnibusBondRegistry,
      'INSERT_STATEMACHINE_ROLE',
      statefulOmnibusBondFactory.address
    );
    await grantPermission(gateKeeper, bondManagerRegistry, 'INSERT_STATEMACHINE_ROLE', bondManagerFactory.address);

    const bondMgrUIHash = await storeIpfsHash(UIDefinitionsBondManager);
    const statefulOBUIHash = await storeIpfsHash(UIDefinitionsSOB);

    await statefulOmnibusBondFactory.setUIFieldDefinitionsHash(statefulOBUIHash);
    await bondManagerFactory.setUIFieldDefinitionsHash(bondMgrUIHash);

    // Store the necessary stateful omnibus bond metadata on ipfs
    ipfsHash = await storeIpfsHash({
      isin: statefulOmnibusBondProperties.isin,
      issuer: statefulOmnibusBondProperties.issuer,
      maturityDate: statefulOmnibusBondProperties.maturityDate,
      issuanceDate: statefulOmnibusBondProperties.issuanceDate,
      currency: statefulOmnibusBondProperties.currency,
    });

    // Create a fresh stateful omnibus bond instance
    statefulOmnibusBond = await StatefulOmnibusBond.new(
      statefulOmnibusBondProperties.name,
      statefulOmnibusBondProperties.symbol,
      statefulOmnibusBondProperties.parValue,
      statefulOmnibusBondProperties.couponRate,
      statefulOmnibusBondProperties.decimals,
      statefulOmnibusBondProperties.frequency,
      gateKeeper.address,
      ipfsHash,
      statefulOBUIHash
    );

    // Give all admin the roles to accounts[0]
    ['MINT_ROLE', 'BURN_ROLE', 'ROLE_ADMIN']
      // convert each role string to a bytes32
      .map((role: string) => web3.utils.fromUtf8(role))
      // Give accounts[0] the roles for the contract instance
      .forEach(async (role: string) => {
        gateKeeper.createPermission(accounts[0], statefulOmnibusBond.address, role, accounts[0]);
      });

    bondManager = await BondManager.new(gateKeeper.address, statefulOmnibusBond.address, 'BOND 1', bondMgrUIHash);

    await gateKeeper.grantPermission(
      bondManager.address,
      statefulOmnibusBond.address,
      web3.utils.fromUtf8('MINT_ROLE')
    );

    await gateKeeper.grantPermission(
      bondManager.address,
      statefulOmnibusBond.address,
      web3.utils.fromUtf8('BURN_ROLE')
    );

    await gateKeeper.createPermission(accounts[0], bondManager.address, web3.utils.fromUtf8('ROLE_ADMIN'), accounts[0]);
  });

  describe('State transitions and state specific methods', () => {
    it('have the correct initial state', async () => {
      expect(await statefulOmnibusBond.getCurrentState()).to.be.equal(
        web3.utils.fromUtf8('STATE_CREATED').padEnd(66, '0')
      );
    });

    it('should only be possible for maker and admin to edit', async () => {
      expect((await statefulOmnibusBond.canEdit()).map((l) => web3.utils.toUtf8(l)).includes('ROLE_ADMIN')).to.be.equal(
        true
      );
      expect((await statefulOmnibusBond.canEdit()).map((l) => web3.utils.toUtf8(l)).includes('ROLE_MAKER')).to.be.equal(
        true
      );
      expect(
        (await statefulOmnibusBond.canEdit()).map((l) => web3.utils.toUtf8(l)).includes('ROLE_CHECKER')
      ).to.be.equal(false);
    });

    it('edit the contract in the initial state', async () => {
      expect(await (await statefulOmnibusBond.decimals()).toNumber()).to.be.equal(3);
      await statefulOmnibusBond.edit(
        statefulOmnibusBondProperties.name,
        statefulOmnibusBondProperties.symbol,
        statefulOmnibusBondProperties.parValue,
        statefulOmnibusBondProperties.couponRate,
        2,
        statefulOmnibusBondProperties.frequency,
        ipfsHash
      );
      expect(await (await statefulOmnibusBond.decimals()).toNumber()).to.be.equal(2);
    });

    it('execute mint request should be rejected if bond is not in active state', async () => {
      let errorMsg;
      await bondManager
        .createMintRequest(500, 10000, web3.utils.fromUtf8('NO'), mintRequestComment1)
        .catch((err) => (errorMsg = err));
      expect(`${errorMsg}`.includes('The bond must be in active state')).to.be.equal(true);
    });

    it('TO_REVIEW', async () => {
      await statefulOmnibusBond.transitionState(web3.utils.fromUtf8('STATE_TO_REVIEW'));
      expect(await statefulOmnibusBond.getCurrentState()).to.be.equal(
        web3.utils.fromUtf8('STATE_TO_REVIEW').padEnd(66, '0')
      );
    });

    it('CHANGES_NEEDED', async () => {
      await statefulOmnibusBond.transitionState(web3.utils.fromUtf8('STATE_CHANGES_NEEDED'));
      expect(await statefulOmnibusBond.getCurrentState()).to.be.equal(
        web3.utils.fromUtf8('STATE_CHANGES_NEEDED').padEnd(66, '0')
      );
    });

    it('edit in state changes needed', async () => {
      await statefulOmnibusBond.transitionState(web3.utils.fromUtf8('STATE_TO_REVIEW'));
      await statefulOmnibusBond.transitionState(web3.utils.fromUtf8('STATE_CHANGES_NEEDED'));

      expect(await statefulOmnibusBond.symbol()).to.be.equal(statefulOmnibusBondProperties.symbol);
      await statefulOmnibusBond.edit(
        statefulOmnibusBondProperties.name,
        'SYMB',
        statefulOmnibusBondProperties.parValue,
        statefulOmnibusBondProperties.couponRate,
        statefulOmnibusBondProperties.decimals,
        statefulOmnibusBondProperties.frequency,
        ipfsHash
      );
      expect(await statefulOmnibusBond.symbol()).to.be.equal('SYMB');
    });

    it('ACTIVE and call the launch callback method', async () => {
      await statefulOmnibusBond.transitionState(web3.utils.fromUtf8('STATE_TO_REVIEW'));
      expect(await (await statefulOmnibusBond._launchDate()).toNumber()).to.be.equal(0);
      await statefulOmnibusBond.transitionState(web3.utils.fromUtf8('STATE_ACTIVE'));
      expect(await statefulOmnibusBond.getCurrentState()).to.be.equal(
        web3.utils.fromUtf8('STATE_ACTIVE').padEnd(66, '0')
      );
      expect(await (await statefulOmnibusBond._launchDate()).toNumber()).to.not.be.equal(0);
    });
  });

  describe('Decimals', () => {
    it('a value of 2 for the par value', async () => {
      expect(await (await statefulOmnibusBond.getDecimalsFor(web3.utils.fromUtf8('_parValue'))).toNumber()).to.be.equal(
        2
      );
    });

    it('return the decimal value defined in the factory (3)', async () => {
      expect(await (await statefulOmnibusBond.getDecimalsFor(web3.utils.fromUtf8('amount'))).toNumber()).to.be.equal(
        statefulOmnibusBondProperties.decimals
      );
    });
  });

  describe('Creating Burn or Mint Requests', () => {
    it('get roles array', async () => {
      await (await bondManager.getRoles())
        .map((bytes32Role) => web3.utils.toUtf8(bytes32Role))
        .forEach((role: string) => {
          expect(['ROLE_ADMIN', 'ROLE_MAKER', 'ROLE_CHECKER'].includes(role)).to.be.equal(true);
        });
    });

    it('request a mint transaction', async () => {
      await bondManager.createMintRequest(500, 10000, web3.utils.fromUtf8('NO'), mintRequestComment1);

      const [status, rType, index, amount, price, , account, requestComment, approveOrDenyComment] = Object.values(
        await bondManager.getByIndex(0)
      );

      expect(web3.utils.toUtf8(`${rType}`)).to.be.equal('MINT');
      expect(web3.utils.toUtf8(`${status}`)).to.be.equal('PENDING');
      expect(index.toString()).to.be.equal('0');
      expect(amount.toString()).to.be.equal('500');
      expect(price.toString()).to.be.equal('10000');
      expect(requestComment).to.be.equal(mintRequestComment1);
      expect(approveOrDenyComment).to.be.equal('');
      expect(account).to.be.equal(accountWM);
    });

    it('approve a mint transaction', async () => {
      await bondManager.approveRequest(0, mintApproveComment);

      const [status, rType, index, amount, price, , account, requestComment, approveOrDenyComment] = Object.values(
        await bondManager.getByIndex(0)
      );

      expect(web3.utils.toUtf8(`${rType}`)).to.be.equal('MINT');
      expect(web3.utils.toUtf8(`${status}`)).to.be.equal('COMPLETED');
      expect(index.toString()).to.be.equal('0');
      expect(amount.toString()).to.be.equal('500');
      expect(price.toString()).to.be.equal('10000');
      expect(requestComment).to.be.equal(mintRequestComment1);
      expect(approveOrDenyComment).to.be.equal(mintApproveComment);
      expect(account).to.be.equal(accountWM);
    });

    it('after mint transaction approved, token must be minted', async () => {
      const [, , , , , , account] = Object.values(await bondManager.getByIndex(0));
      expect(await (await statefulOmnibusBond.balanceOf(`${account}`)).toString()).to.be.equal('500');
    });

    it('deny a mint transaction', async () => {
      await bondManager.createMintRequest(300, 6000, web3.utils.fromUtf8('NO'), mintRequestComment2);
      await bondManager.denyRequest(1, mintDenyComment);

      const [status, rType, index, amount, price, , account, requestComment, approveOrDenyComment] = Object.values(
        await bondManager.getByIndex(1)
      );

      expect(web3.utils.toUtf8(`${rType}`)).to.be.equal('MINT');
      expect(web3.utils.toUtf8(`${status}`)).to.be.equal('DENIED');
      expect(index.toString()).to.be.equal('1');
      expect(amount.toString()).to.be.equal('300');
      expect(price.toString()).to.be.equal('6000');
      expect(requestComment).to.be.equal(mintRequestComment2);
      expect(approveOrDenyComment).to.be.equal(mintDenyComment);
      expect(account).to.be.equal(accountWM);
    });

    it('denied transaction cannot be approved', async () => {
      let errorMsg;
      const [status, , index] = Object.values(await bondManager.getByIndex(1));
      expect(web3.utils.toUtf8(`${status}`)).to.be.equal('DENIED');
      await bondManager.approveRequest(index, mintApproveComment).catch((err) => (errorMsg = err));
      expect(`${errorMsg}`.includes('The request should be pending')).to.be.equal(true);
    });

    it('request a burn transaction', async () => {
      await bondManager.createBurnRequest(200, 10000, accountWM, burnRequestComment1);
      const [status, rType, index, amount, price, , account, requestComment, approveOrDenyComment] = Object.values(
        await bondManager.getByIndex(2)
      );

      expect(web3.utils.toUtf8(`${rType}`)).to.be.equal('BURN');
      expect(web3.utils.toUtf8(`${status}`)).to.be.equal('PENDING');
      expect(index.toString()).to.be.equal('2');
      expect(amount.toString()).to.be.equal('200');
      expect(price.toString()).to.be.equal('10000');
      expect(requestComment).to.be.equal(burnRequestComment1);
      expect(approveOrDenyComment).to.be.equal('');
      expect(account).to.be.equal(accountWM);
    });

    it('approve a burn transaction', async () => {
      await bondManager.approveRequest(2, burnApproveComment);

      const [status, rType, index, amount, price, , account, requestComment, approveOrDenyComment] = Object.values(
        await bondManager.getByIndex(2)
      );

      expect(web3.utils.toUtf8(`${rType}`)).to.be.equal('BURN');
      expect(web3.utils.toUtf8(`${status}`)).to.be.equal('COMPLETED');
      expect(index.toString()).to.be.equal('2');
      expect(amount.toString()).to.be.equal('200');
      expect(price.toString()).to.be.equal('10000');
      expect(requestComment).to.be.equal(burnRequestComment1);
      expect(approveOrDenyComment).to.be.equal(burnApproveComment);
      expect(account).to.be.equal(accountWM);
    });

    it('after burn transaction approved, token must be burnt', async () => {
      const [, , , , , , account] = Object.values(await bondManager.getByIndex(2));
      expect(await (await statefulOmnibusBond.balanceOf(`${account}`)).toString()).to.be.equal('300'); // 500 - 200
    });

    it('deny a burn transaction', async () => {
      await bondManager.createBurnRequest(300, 6000, account2, burnRequestComment2);
      await bondManager.denyRequest(3, burnDenyComment);

      const [status, rType, index, amount, price, , account, requestComment, approveOrDenyComment] = Object.values(
        await bondManager.getByIndex(3)
      );

      expect(web3.utils.toUtf8(`${rType}`)).to.be.equal('BURN');
      expect(web3.utils.toUtf8(`${status}`)).to.be.equal('DENIED');
      expect(index.toString()).to.be.equal('3');
      expect(amount.toString()).to.be.equal('300');
      expect(price.toString()).to.be.equal('6000');
      expect(requestComment).to.be.equal(burnRequestComment2);
      expect(approveOrDenyComment).to.be.equal(burnDenyComment);
      expect(account).to.be.equal(account2);
    });
  });

  describe('Bond related', () => {
    it('transfer tokenized bonds in the active state', async () => {
      const holder1Balance = await statefulOmnibusBond.balanceOf(accountWM);
      await statefulOmnibusBond.transfer(accountWM, account2, holder1Balance.div(web3.utils.toBN(2)), 10000);
      expect(await (await statefulOmnibusBond.balanceOf(accountWM)).toString()).to.be.equal(
        holder1Balance.div(web3.utils.toBN(2)).toString()
      );
      expect(await (await statefulOmnibusBond.balanceOf(account2)).toString()).to.be.equal(
        holder1Balance.div(web3.utils.toBN(2)).toString()
      );
    });

    it('MATURED and mature', async () => {
      expect(await (await statefulOmnibusBond.balanceOf(accountWM)).toString()).to.not.be.equal('0');
      expect(await (await statefulOmnibusBond.balanceOf(account2)).toString()).to.not.be.equal('0');
      await statefulOmnibusBond.transitionState(web3.utils.fromUtf8('STATE_MATURED'));
      expect(await statefulOmnibusBond.getCurrentState()).to.be.equal(
        web3.utils.fromUtf8('STATE_MATURED').padEnd(66, '0')
      );
      expect(await (await statefulOmnibusBond.balanceOf(accountWM)).toString()).to.be.equal('0');
      expect(await (await statefulOmnibusBond.balanceOf(account2)).toString()).to.be.equal('0');
    });
  });

  describe('Holder iban and balance getters', () => {
    it('number of token holders', async () => {
      expect(await (await statefulOmnibusBond.getIndexLength()).toNumber()).to.be.equal(2);
    });

    it('info and balance for an index', async () => {
      const holder1Info = await statefulOmnibusBond.getByIndex(0);
      const holder1Balance = await statefulOmnibusBond.balanceOf(accountWM);
      expect((holder1Info as any).holder).to.be.equal(accountWM);
      expect((holder1Info as any).balance.toString()).to.be.equal(holder1Balance.toString());
    });

    it('an iban account', async () => {
      const holder1Info = await statefulOmnibusBond.getByKey(accountWM);
      const holder1Balance = await statefulOmnibusBond.balanceOf(accountWM);
      expect((holder1Info as any).holder).to.be.equal(accountWM);
      expect((holder1Info as any).balance.toString()).to.be.equal(holder1Balance.toString());
    });
  });
});
