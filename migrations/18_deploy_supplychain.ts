import { deployStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { BuyerRoleRegistryContract } from '../types/truffle-contracts/BuyerRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { SupplyChainFactoryContract, SupplyChainFactoryInstance } from '../types/truffle-contracts/SupplyChainFactory';
import { SupplyChainRegistryContract } from '../types/truffle-contracts/SupplyChainRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const SupplyChainRegistry: SupplyChainRegistryContract = artifacts.require('SupplyChainRegistry');
const SupplyChainFactory: SupplyChainFactoryContract = artifacts.require('SupplyChainFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const BuyerRoleRegistry: BuyerRoleRegistryContract = artifacts.require('BuyerRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('SUPPLYCHAIN')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/supplychain/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      SupplyChainRegistry,
      SupplyChainFactory,
      [AdminRoleRegistry, BuyerRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

    const SupplyChains = [
      {
        Order_Number: '5YJXCAE45GFF00001',

        Item_Name: 'Car',
        Quantity: '425382',
        Order_date: 1558362520,
        Price: '55000',
        Delivery_Duration: '6 Months',
        Delivery_Address: 'Street 4, City Central',
      },
      {
        Order_Number: '5YJRE1A31A1P01234',

        Item_Name: 'Car',
        Quantity: '123054',
        Order_date: 1558062520,
        Price: '55000',
        Delivery_Duration: '8 Months',
        Delivery_Address: 'Street 5, City Square',
      },
    ];

    for (const SupplyChain of SupplyChains) {
      await createSupplyChain(factory, SupplyChain);
    }
  }
};

async function createSupplyChain(
  factory: SupplyChainFactoryInstance,
  SupplyChain: {
    Order_Number: string;

    Item_Name: string;
    Quantity: string;
    Order_date: number;
    Price: string;
    Delivery_Duration: string;
    Delivery_Address: string;
  }
) {
  const ipfsHash = await storeIpfsJsonData({
    Item_Name: SupplyChain.Item_Name,
    Quantity: SupplyChain.Quantity,
    Order_date: SupplyChain.Order_date,
    Price: SupplyChain.Price,
    Delivery_Duration: SupplyChain.Delivery_Duration,
    Delivery_Address: SupplyChain.Delivery_Address,
  });
  await factory.create(SupplyChain.Order_Number, ipfsHash);
}
