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

        Bank: 'Car',
        Type: '425382',
        Date: 1558362520,
        Value: '55000',
        Duration: '6 Months',
        Beneficiary: 'Street 4, City Central',
      },
      {
        SAP_Number: '5YJRE1A31A1P01234',

        Bank: 'Car',
        Type: '123054',
        Date: 1558062520,
        Value: '55000',
        Duration: '8 Months',
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
    Type: string;
    Date: number;
    Value: string;
    Duration: string;
    Beneficiary: string;
  }
) {
  const ipfsHash = await storeIpfsJsonData({
    Bank: TradeFinance.Bank,
    Type: TradeFinance.Type,
    Date: TradeFinance.Date,
    Value: TradeFinance.Value,
    Duration: TradeFinance.Duration,
    Beneficiary: TradeFinance.Beneficiary,
  });
  await factory.create(TradeFinance.SAP_Number, ipfsHash);
}
