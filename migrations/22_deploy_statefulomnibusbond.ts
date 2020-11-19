import dayjs from 'dayjs';
import faker from 'faker';
import web3 from 'web3';

import {
  createPermission,
  grantPermission,
  storeUIDefinitions,
  getNewAddressFromEvents,
} from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { MakerRoleRegistryContract } from '../types/truffle-contracts/MakerRoleRegistry';
import { StatefulOmnibusBondContract } from '../types/truffle-contracts/StatefulOmnibusBond';
import { StatefulOmnibusBondFactoryContract } from '../types/truffle-contracts/StatefulOmnibusBondFactory';
import { BondManagerFactoryContract } from '../types/truffle-contracts/BondManagerFactory';
import { StatefulOmnibusBondRegistryContract } from '../types/truffle-contracts/StatefulOmnibusBondRegistry';
import { BondManagerRegistryContract } from 'types/truffle-contracts';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const StatefulOmnibusBondRegistry: StatefulOmnibusBondRegistryContract = artifacts.require(
  'StatefulOmnibusBondRegistry'
);

const BondManagerRegistry: BondManagerRegistryContract = artifacts.require('BondManagerRegistry');
const StatefulOmnibusBond: StatefulOmnibusBondContract = artifacts.require('StatefulOmnibusBond');
const StatefulOmnibusBondFactory: StatefulOmnibusBondFactoryContract = artifacts.require('StatefulOmnibusBondFactory');
const BondManagerFactory: BondManagerFactoryContract = artifacts.require('BondManagerFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const MakerRoleRegistry: MakerRoleRegistryContract = artifacts.require('MakerRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('STATEFULOMNIBUSBONDS')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitionsStatefulOmnibusBond = require('../../contracts/statefulomnibusbonds/UIDefinitionsSOB.json');

    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitionsBondManager = require('../../contracts/statefulomnibusbonds/UIDefinitionsBondManager.json');

    const dGateKeeper = await GateKeeper.deployed();

    await deployer.deploy(StatefulOmnibusBondRegistry, dGateKeeper.address);
    const deployedSOBRegistry = await StatefulOmnibusBondRegistry.deployed();

    await deployer.deploy(BondManagerRegistry, dGateKeeper.address);
    const deployedBMRegistry = await BondManagerRegistry.deployed();

    await createPermission(dGateKeeper, deployedSOBRegistry, 'INSERT_STATEMACHINE_ROLE', accounts[0], accounts[0]);

    await createPermission(dGateKeeper, deployedBMRegistry, 'INSERT_STATEMACHINE_ROLE', accounts[0], accounts[0]);

    await deployer.deploy(BondManagerFactory, dGateKeeper.address, deployedBMRegistry.address);
    const deployedBMFactory = await BondManagerFactory.deployed();

    await createPermission(dGateKeeper, deployedBMFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);

    // set the permissions on the factory
    await grantPermission(dGateKeeper, dGateKeeper, 'CREATE_PERMISSIONS_ROLE', deployedBMFactory.address);
    await grantPermission(dGateKeeper, deployedBMRegistry, 'INSERT_STATEMACHINE_ROLE', deployedBMFactory.address);

    if (Object.keys(uiDefinitionsBondManager).length) {
      const hash = storeIpfsHash
        ? await storeIpfsHash(uiDefinitionsBondManager)
        : await storeUIDefinitions(uiDefinitionsBondManager);
      await deployedBMFactory.setUIFieldDefinitionsHash(hash);
    }

    await deployer.deploy(
      StatefulOmnibusBondFactory,
      dGateKeeper.address,
      deployedSOBRegistry.address,
      deployedBMFactory.address
    );
    const deployedSOBFactory = await StatefulOmnibusBondFactory.deployed();

    // Give admin permission to accounts[0]
    await createPermission(dGateKeeper, deployedSOBFactory, 'CREATE_STATEMACHINE_ROLE', accounts[0], accounts[0]);
    await createPermission(dGateKeeper, deployedSOBFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);

    // give permission to the SOB factory to create a BondManager
    await createPermission(
      dGateKeeper,
      deployedBMFactory,
      'CREATE_STATEMACHINE_ROLE',
      accounts[0],
      deployedSOBFactory.address
    );

    // Set create expense permissions on the relevant role registries
    await grantPermission(dGateKeeper, deployedSOBFactory, 'CREATE_STATEMACHINE_ROLE', AdminRoleRegistry.address);
    await grantPermission(dGateKeeper, deployedSOBFactory, 'CREATE_STATEMACHINE_ROLE', MakerRoleRegistry.address);

    // set the permissions on the factory
    await grantPermission(dGateKeeper, dGateKeeper, 'CREATE_PERMISSIONS_ROLE', deployedSOBFactory.address);
    await grantPermission(dGateKeeper, deployedSOBRegistry, 'INSERT_STATEMACHINE_ROLE', deployedSOBFactory.address);

    if (Object.keys(uiDefinitionsStatefulOmnibusBond).length) {
      const hash = storeIpfsHash
        ? await storeIpfsHash(uiDefinitionsStatefulOmnibusBond)
        : await storeUIDefinitions(uiDefinitionsStatefulOmnibusBond);
      await deployedSOBFactory.setUIFieldDefinitionsHash(hash);
    }

    // deploy example contracts
    for (let i = 0; i < 3; i++) {
      const interest = (faker.random.number(15) + 1) * 100;
      const issuanceDate = dayjs();
      const duration = (i + 1) * 12;
      const maturityDate = issuanceDate.add(duration, 'month');
      const periodString = i % 2 === 0 ? 'ANN' : 'SEMI';
      const parValue = (i + 1) * 1000;
      const issuer = faker.company.companyName();

      const statefulOmnibusBond = {
        name: `BOND ${interest}% ${maturityDate.format('YY-MM-DD')} ${periodString}`,
        isin: faker.finance.iban(),
        symbol: issuer.substring(0, 4),
        frequency: periodString,
        interest,
        decimals: 2,
        issuer: issuer,
        maturityDate: maturityDate.unix(),
        issuanceDate: issuanceDate.unix(),
        currency: 'Singapore Dollar',
        parValue,
        couponValue: Math.floor((interest / 100) * parValue),
      };

      const ipfsHash = await storeIpfsHash({
        isin: statefulOmnibusBond.isin,
        issuer: statefulOmnibusBond.issuer,
        maturityDate: statefulOmnibusBond.maturityDate,
        issuanceDate: statefulOmnibusBond.issuanceDate,
        currency: 'Singapore Dollar',
      });

      const tx = await deployedSOBFactory.create(
        statefulOmnibusBond.name,
        statefulOmnibusBond.symbol,
        statefulOmnibusBond.parValue,
        statefulOmnibusBond.interest,
        statefulOmnibusBond.decimals,
        web3.utils.toHex(statefulOmnibusBond.frequency),
        ipfsHash
      );

      if (i === 0) {
        const sobAddress = getNewAddressFromEvents(tx, 'StatefulOmnibusBondCreated');
        // tslint:disable-next-line: no-any
        const sob = await StatefulOmnibusBond.at(sobAddress);
        await sob.transitionState(await sob.STATE_TO_REVIEW());
        await sob.transitionState(await sob.STATE_ACTIVE());
      }
    }
  }
};
