import { deployStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { GenericFactoryContract, GenericFactoryInstance } from '../types/truffle-contracts/GenericFactory';
import { GenericRegistryContract } from '../types/truffle-contracts/GenericRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const GenericRegistry: GenericRegistryContract = artifacts.require('GenericRegistry');
const GenericFactory: GenericFactoryContract = artifacts.require('GenericFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('GENERIC')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/genericstatemachine/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      GenericRegistry,
      GenericFactory,
      [AdminRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

    // Creation of a test generic SM
    const Generics = [
      {
        param1: 'a',
        param2: '0x3ad941908e73d2214d08237e90cfce11cd490c16',
        param3: 0,
        type: 'd',
        place: 'Belgium',
        creationDate: 1558362520,
        optionalParameter: 'd',
      },
    ];
    for (const generic of Generics) {
      await createGeneric(factory, generic);
    }
  }
};

async function createGeneric(
  factory: GenericFactoryInstance,
  generic: {
    param1: string;
    param2: string;
    param3: number;
    place: string;
    creationDate: number;
    type: string;
    optionalParameter?: string;
  }
) {
  const ipfsHash = await storeIpfsJsonData({
    place: generic.place,
    type: generic.type,
    creationDate: generic.creationDate,
    optionalParameter: generic.optionalParameter,
  });
  await factory.create(generic.param1, generic.param2, generic.param3, ipfsHash);
}
