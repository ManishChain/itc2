import { deployERC20TokenSystem } from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { ShareContract } from '../types/truffle-contracts/Share';
import { ShareFactoryContract } from '../types/truffle-contracts/ShareFactory';
import { ShareRegistryContract } from '../types/truffle-contracts/ShareRegistry';
import { UserRoleRegistryContract } from '../types/truffle-contracts/UserRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const Share: ShareContract = artifacts.require('Share');
const ShareFactory: ShareFactoryContract = artifacts.require('ShareFactory');
const ShareRegistry: ShareRegistryContract = artifacts.require('ShareRegistry');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry: UserRoleRegistryContract = artifacts.require('UserRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('SHARES')) {
    const dGateKeeper = await GateKeeper.deployed();

    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/share/UIDefinitions.json');
    await deployERC20TokenSystem(
      {
        gatekeeper: dGateKeeper,
        registry: { contract: ShareRegistry, extraParams: [] },
        factory: { contract: ShareFactory, extraParams: [] },
        token: {
          contract: Share,
          instances: [
            {
              name: 'Apple',
              decimals: 2,
              extraParams: [],
              issuance: [
                {
                  recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                  amount: 4500,
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
