import { deployStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';
import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { MakerRoleRegistryContract } from '../types/truffle-contracts/MakerRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import {
  TradeFinanceFactoryContract,
  TradeFinanceFactoryInstance,
} from '../types/truffle-contracts/TradeFinanceFactory';
import { TradeFinanceRegistryContract } from '../types/truffle-contracts/TradeFinanceRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const TradeFinanceRegistry: TradeFinanceRegistryContract = artifacts.require('TradeFinanceRegistry');
const TradeFinanceFactory: TradeFinanceFactoryContract = artifacts.require('TradeFinanceFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const BuyerRoleRegistry: MakerRoleRegistryContract = artifacts.require('MakerRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('TRADE')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/trade/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      TradeFinanceRegistry,
      TradeFinanceFactory,
      [AdminRoleRegistry, BuyerRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

    const TradeFinances = [
      {
        SAP_Number: '5YJXCAE45GFF00001',

        Bank: 'SBI',
        Date: '1558362520',
        Value: '55000',
        Beneficiary: 'Street 4, City Central',
      },
      {
        SAP_Number: '5YJRE1A31A1P01234',

        Bank: 'ICICI',
        Date: '1558362520',
        Value: '55000',
        Beneficiary: 'Street 5, City Square',
      },
    ];

    for (const TradeFinance of TradeFinances) {
      await createTradeFinance(factory, TradeFinance);
    }
  }
};

async function createTradeFinance(
  factory: TradeFinanceFactoryInstance,
  TradeFinance: {
    SAP_Number: string;
    Bank: string;
    Date: string;
    Value: string;
    Beneficiary: string;
  }
) {
  const ipfsHash = await storeIpfsJsonData({
  
  });
  await factory.create(TradeFinance.SAP_Number, TradeFinance.Bank,  TradeFinance.Date, TradeFinance.Value,  TradeFinance.Beneficiary, ipfsHash);
}
