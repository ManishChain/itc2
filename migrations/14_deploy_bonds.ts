import { createPermission, getNewAddressFromEvents, grantPermission } from '@settlemint/enteth-migration-utils';
import dayjs from 'dayjs';
import faker from 'faker';

import { BondContract } from '../types/truffle-contracts/Bond';
import { BondFactoryContract } from '../types/truffle-contracts/BondFactory';
import { BondRegistryContract } from '../types/truffle-contracts/BondRegistry';
import { CurrencyRegistryContract } from '../types/truffle-contracts/CurrencyRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';

const BondFactory: BondFactoryContract = artifacts.require('BondFactory');
const BondRegistry: BondRegistryContract = artifacts.require('BondRegistry');
const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const CurrencyRegistry: CurrencyRegistryContract = artifacts.require('CurrencyRegistry');
const Bond: BondContract = artifacts.require('Bond');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { storeIpfsHash, enabledFeatures } = require('../../truffle-config.js');

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('BONDS')) {
    const gateKeeper = await GateKeeper.deployed();
    const currencyRegistry = await CurrencyRegistry.deployed();
    const currencies: Array<{ value: string; label: string }> = [];
    const currencyLength = await currencyRegistry.getIndexLength();
    for (let i = 0; i < currencyLength.toNumber(); i++) {
      const currency = await currencyRegistry.getByIndex(i);
      currencies.push({ value: currency[1], label: currency[0] });
    }
    // Bonds
    await deployer.deploy(BondRegistry, gateKeeper.address);
    const bondRegistry = await BondRegistry.deployed();
    await createPermission(gateKeeper, bondRegistry, 'LIST_TOKEN_ROLE', accounts[0], accounts[0]);
    await deployer.deploy(BondFactory, bondRegistry.address, gateKeeper.address);
    const bondFactory = await BondFactory.deployed();
    await createPermission(gateKeeper, bondFactory, 'CREATE_TOKEN_ROLE', accounts[0], accounts[0]);
    await grantPermission(gateKeeper, bondRegistry, 'LIST_TOKEN_ROLE', bondFactory.address);
    await grantPermission(gateKeeper, gateKeeper, 'CREATE_PERMISSIONS_ROLE', bondFactory.address);
    await createPermission(gateKeeper, bondFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
    // two dirs up, because it is compiled into ./dist/migrations
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/bonds/UIDefinitions.json');
    uiDefinitions.selectFields.parCurrency = currencies;
    const hash = await storeIpfsHash(uiDefinitions);
    await bondFactory.setUIFieldDefinitionsHash(hash);

    for (let i = 0; i < 10; i++) {
      const name = faker.company.companyName();
      const decimals = 2;
      const duration = i % 2 ? 24 : 60;
      const period = i % 2 ? 6 : 12;
      const periodString = i % 2 ? 'SEMI' : 'ANN';
      const interest = parseInt(faker.finance.amount(1, 12, 0), 10);
      const issuanceDate = i < 5 ? dayjs().subtract(3, 'year').add(i, 'month') : dayjs().add(i, 'month');
      const ipfsHash = await storeIpfsHash({
        isin: faker.finance.iban(),
        issuer: name,
      });

      const tx = await bondFactory.createToken(
        `BOND ${interest}% ${issuanceDate.add(duration * 4, 'week').format('YY-MM-DD')} ${periodString}`,
        10 ** decimals * (parseInt(faker.finance.amount(5, 100, 0), 10) * 100),
        currencies[0].value,
        duration,
        interest,
        period,
        decimals,
        ipfsHash
      );
      const bondAddress = getNewAddressFromEvents(tx, 'TokenCreated');
      // tslint:disable-next-line: no-any
      const bond = await Bond.at(bondAddress);
      await bond.setIssuanceDate(issuanceDate.unix());
      if (issuanceDate.isBefore(dayjs())) {
        await bond.launch(issuanceDate.add(1, 'day').unix());
      }
      await bond.mint(accounts[0], 10 ** decimals * faker.random.number(1000));
    }
  }
};
