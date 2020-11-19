import { deployERC20TokenSystem } from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { LoanContract } from '../types/truffle-contracts/Loan';
import { LoanFactoryContract } from '../types/truffle-contracts/LoanFactory';
import { LoanRegistryContract } from '../types/truffle-contracts/LoanRegistry';
import { UserRoleRegistryContract } from '../types/truffle-contracts/UserRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const Loan: LoanContract = artifacts.require('Loan');
const LoanFactory: LoanFactoryContract = artifacts.require('LoanFactory');
const LoanRegistry: LoanRegistryContract = artifacts.require('LoanRegistry');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry: UserRoleRegistryContract = artifacts.require('UserRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('LOANS')) {
    const dGateKeeper = await GateKeeper.deployed();

    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/loan/UIDefinitions.json');
    await deployERC20TokenSystem(
      {
        gatekeeper: dGateKeeper,
        registry: { contract: LoanRegistry, extraParams: [] },
        factory: { contract: LoanFactory, extraParams: [] },
        token: {
          contract: Loan,
          instances: [
            {
              name: 'Personal loans',
              decimals: 2,
              extraParams: [],
              issuance: [
                {
                  recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                  amount: 500,
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
