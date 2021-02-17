import { deployStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { BuyerRoleRegistryContract } from '../types/truffle-contracts/BuyerRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import {
  SupplyChainFinanceFactoryContract,
  SupplyChainFinanceFactoryInstance,
} from '../types/truffle-contracts/SupplyChainFinanceFactory';
import { SupplyChainFinanceRegistryContract } from '../types/truffle-contracts/SupplyChainFinanceRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const SupplyChainFinanceRegistry: SupplyChainFinanceRegistryContract = artifacts.require('SupplyChainFinanceRegistry');
const SupplyChainFinanceFactory: SupplyChainFinanceFactoryContract = artifacts.require('SupplyChainFinanceFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const BuyerRoleRegistry: BuyerRoleRegistryContract = artifacts.require('BuyerRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('SUPPLYFINANCE')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/supplychain/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      SupplyChainFinanceRegistry,
      SupplyChainFinanceFactory,
      [AdminRoleRegistry, BuyerRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

    const SupplyChainFinances = [
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

    for (const SupplyChainFinance of SupplyChainFinances) {
      await createSupplyChainFinance(factory, SupplyChainFinance);
    }
  }
};

async function createSupplyChainFinance(
  factory: SupplyChainFinanceFactoryInstance,
  SupplyChainFinance: {
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
    Item_Name: SupplyChainFinance.Item_Name,
    Quantity: SupplyChainFinance.Quantity,
    Order_date: SupplyChainFinance.Order_date,
    Price: SupplyChainFinance.Price,
    Delivery_Duration: SupplyChainFinance.Delivery_Duration,
    Delivery_Address: SupplyChainFinance.Delivery_Address,
  });
  await factory.create(SupplyChainFinance.Order_Number, ipfsHash);
}
