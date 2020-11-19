import { deployStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import {
  KnowYourBusinessFactoryContract,
  KnowYourBusinessFactoryInstance,
} from '../types/truffle-contracts/KnowYourBusinessFactory';
import { KnowYourBusinessRegistryContract } from '../types/truffle-contracts/KnowYourBusinessRegistry';
import { RequesterRoleRegistryContract } from '../types/truffle-contracts/RequesterRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const KnowYourBusinessRegistry: KnowYourBusinessRegistryContract = artifacts.require('KnowYourBusinessRegistry');
const KnowYourBusinessFactory: KnowYourBusinessFactoryContract = artifacts.require('KnowYourBusinessFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const RequesterRoleRegistry: RequesterRoleRegistryContract = artifacts.require('RequesterRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('KYB')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/knowyourbusiness/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      KnowYourBusinessRegistry,
      KnowYourBusinessFactory,
      [AdminRoleRegistry, RequesterRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

    const KnowYourBusinesss = [
      {
        Name: 'Good_Business',
        Address: 'Street-1',
        Products: 'Premium_Products',
        Year_of_Incorporation: '1995',
        Registration_Number: '554848',
        Contact_Details: 'abc@mail.com',
      },
    ];
    for (const KnowYourBusiness of KnowYourBusinesss) {
      await createKnowYourBusiness(factory, KnowYourBusiness);
    }
  }
};

async function createKnowYourBusiness(
  factory: KnowYourBusinessFactoryInstance,
  KnowYourBusiness: {
    Name: string;

    Address: string;
    Products: string;
    Year_of_Incorporation: string;
    Registration_Number: string;
    Contact_Details: string;
  }
) {
  const ipfsHash = await storeIpfsJsonData({
    Address: KnowYourBusiness.Address,
    Products: KnowYourBusiness.Products,
    Year_of_Incorporation: KnowYourBusiness.Year_of_Incorporation,
    Registration_Number: KnowYourBusiness.Registration_Number,
    Contact_Details: KnowYourBusiness.Contact_Details,
  });
  await factory.create(KnowYourBusiness.Name, ipfsHash);
}
