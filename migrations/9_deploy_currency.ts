import { deployERC20TokenSystem } from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { CurrencyContract } from '../types/truffle-contracts/Currency';
import { CurrencyFactoryContract } from '../types/truffle-contracts/CurrencyFactory';
import { CurrencyRegistryContract } from '../types/truffle-contracts/CurrencyRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { UserRoleRegistryContract } from '../types/truffle-contracts/UserRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const Currency: CurrencyContract = artifacts.require('Currency');
const CurrencyFactory: CurrencyFactoryContract = artifacts.require('CurrencyFactory');
const CurrencyRegistry: CurrencyRegistryContract = artifacts.require('CurrencyRegistry');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry: UserRoleRegistryContract = artifacts.require('UserRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
const found = (features: string[]) => enabledFeatures().some((feature: string) => features.includes(feature));

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (found(['CURRENCY', 'BONDS'])) {
    const dGateKeeper = await GateKeeper.deployed();

    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/currency/UIDefinitions.json');
    await deployERC20TokenSystem(
      {
        gatekeeper: dGateKeeper,
        registry: { contract: CurrencyRegistry, extraParams: [] },
        factory: { contract: CurrencyFactory, extraParams: [] },
        token: {
          contract: Currency,
          instances: [
            {
              name: 'Euro',
              decimals: 2,
              extraParams: [],
              issuance: [
                {
                  recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                  amount: 10000,
                },
              ],
            },
            {
              name: 'Dollar',
              decimals: 2,
              extraParams: [],
              issuance: [
                {
                  recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                  amount: 5000,
                },
              ],
            },
          ],
        },
        roles: [AdminRoleRegistry],
      },
      accounts[0],
      uiDefinitions,
      deployer,
      storeIpfsHash
    );
  }
};
