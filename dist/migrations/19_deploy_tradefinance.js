"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const TradeFinanceRegistry = artifacts.require('TradeFinanceRegistry');
const TradeFinanceFactory = artifacts.require('TradeFinanceFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const BuyerRoleRegistry = artifacts.require('MakerRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('TRADE')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/trade/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, TradeFinanceRegistry, TradeFinanceFactory, [AdminRoleRegistry, BuyerRoleRegistry], uiDefinitions, storeIpfsHash);
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
async function createTradeFinance(factory, TradeFinance) {
    const ipfsHash = await enteth_migration_utils_1.storeIpfsJsonData({});
    await factory.create(TradeFinance.SAP_Number, TradeFinance.Bank, TradeFinance.Date, TradeFinance.Value, TradeFinance.Beneficiary, ipfsHash);
}
//# sourceMappingURL=19_deploy_tradefinance.js.map