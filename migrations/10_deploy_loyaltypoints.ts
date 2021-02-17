import { deployERC20TokenSystem } from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { LoyaltyPointContract } from '../types/truffle-contracts/LoyaltyPoint';
import { LoyaltyPointFactoryContract } from '../types/truffle-contracts/LoyaltyPointFactory';
import { LoyaltyPointRegistryContract } from '../types/truffle-contracts/LoyaltyPointRegistry';
import { UserRoleRegistryContract } from '../types/truffle-contracts/UserRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const LoyaltyPoint: LoyaltyPointContract = artifacts.require('LoyaltyPoint');
const LoyaltyPointFactory: LoyaltyPointFactoryContract = artifacts.require('LoyaltyPointFactory');
const LoyaltyPointRegistry: LoyaltyPointRegistryContract = artifacts.require('LoyaltyPointRegistry');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry: UserRoleRegistryContract = artifacts.require('UserRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('LOYALTYPOINTS')) {
    const dGateKeeper = await GateKeeper.deployed();

    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/loyaltypoint/UIDefinitions.json');
    await deployERC20TokenSystem(
      {
        gatekeeper: dGateKeeper,
        registry: { contract: LoyaltyPointRegistry, extraParams: [] },
        factory: { contract: LoyaltyPointFactory, extraParams: [] },
        token: {
          contract: LoyaltyPoint,
          instances: [
            {
              name: 'Skywards',
              decimals: 8,
              extraParams: [],
              issuance: [
                {
                  recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                  amount: 45000,
                },
              ],
            },
            {
              name: 'Miles and More',
              decimals: 18,
              extraParams: [],
              issuance: [
                {
                  recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                  amount: 123000,
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
