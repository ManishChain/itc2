import { deployStateMachineSystem, getNewAddressFromEvents } from '@settlemint/enteth-migration-utils';
import dayjs from 'dayjs';
import faker from 'faker';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { CheckerRoleRegistryContract } from '../types/truffle-contracts/CheckerRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { MakerRoleRegistryContract } from '../types/truffle-contracts/MakerRoleRegistry';
import { StatefulBondContract } from '../types/truffle-contracts/StatefulBond';
import { StatefulBondFactoryContract } from '../types/truffle-contracts/StatefulBondFactory';
import { StatefulBondRegistryContract } from '../types/truffle-contracts/StatefulBondRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const StatefulBond: StatefulBondContract = artifacts.require('StatefulBond');
const StatefulBondRegistry: StatefulBondRegistryContract = artifacts.require('StatefulBondRegistry');
const StatefulBondFactory: StatefulBondFactoryContract = artifacts.require('StatefulBondFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const MakerRoleRegistry: MakerRoleRegistryContract = artifacts.require('MakerRoleRegistry');
const CheckerRoleRegistry: CheckerRoleRegistryContract = artifacts.require('CheckerRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('STATEFULBONDS')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/statefulbonds/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      StatefulBondRegistry,
      StatefulBondFactory,
      [AdminRoleRegistry, MakerRoleRegistry, CheckerRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

    for (let i = 0; i < 5; i++) {
      const interest = (faker.random.number(15) + 1) * 100;
      const issuanceDate = dayjs();
      const duration = (i + 1) * 12;
      const maturityDate = issuanceDate.add(duration, 'month');
      const periodString = i % 2 === 0 ? 'ANN' : 'SEMI';
      const parValue = (i + 1) * 1000;

      const statefulBond = {
        name: `BOND ${interest}% ${maturityDate.format('YY-MM-DD')} ${periodString}`,
        isin: faker.finance.iban(),
        frequency: periodString,
        interest,
        decimals: 2,
        issuer: faker.company.companyName(),
        maturityDate: maturityDate.unix(),
        issuanceDate: issuanceDate.unix(),
        currency: 'Singapore Dollar',
        parValue,
        inFlight: i === 3 ? web3.utils.toHex('YES') : web3.utils.toHex('NO'),
        couponValue: Math.floor((interest / 100) * parValue),
      };

      const ipfsHash = await storeIpfsHash({
        isin: statefulBond.isin,
        issuer: statefulBond.issuer,
        maturityDate: statefulBond.maturityDate,
        issuanceDate: statefulBond.issuanceDate,
        currency: 'Singapore Dollar',
      });
      const tx = await factory.create(
        statefulBond.name,
        statefulBond.parValue,
        statefulBond.interest,
        statefulBond.decimals,
        statefulBond.inFlight,
        web3.utils.toHex(statefulBond.frequency),
        ipfsHash
      );

      if (i !== 4) {
        const bondAddress = getNewAddressFromEvents(tx, 'TokenCreated');
        // tslint:disable-next-line: no-any
        const bond = await StatefulBond.at(bondAddress);
        await bond.transitionState(await bond.STATE_TO_REVIEW());
        await bond.launch(dayjs().unix());
        await bond.transitionState(await bond.STATE_READY_FOR_TOKENIZATION());
        await bond.requestTokenization(faker.random.number(1000) * 100);
        await bond.transitionState(await bond.STATE_TOKENIZATION_REQUEST());
        await bond.transitionState(await bond.STATE_TOKENIZATION_APPROVED());
      }
    }
  }
};
