"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const SupplyChainFinanceRegistry = artifacts.require('SupplyChainFinanceRegistry');
const SupplyChainFinanceFactory = artifacts.require('SupplyChainFinanceFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const BuyerRoleRegistry = artifacts.require('BuyerRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('SUPPLYFINANCE')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/supplychain/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, SupplyChainFinanceRegistry, SupplyChainFinanceFactory, [AdminRoleRegistry, BuyerRoleRegistry], uiDefinitions, storeIpfsHash);
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
async function createSupplyChainFinance(factory, SupplyChainFinance) {
    const ipfsHash = await enteth_migration_utils_1.storeIpfsJsonData({
        Item_Name: SupplyChainFinance.Item_Name,
        Quantity: SupplyChainFinance.Quantity,
        Order_date: SupplyChainFinance.Order_date,
        Price: SupplyChainFinance.Price,
        Delivery_Duration: SupplyChainFinance.Delivery_Duration,
        Delivery_Address: SupplyChainFinance.Delivery_Address,
    });
    await factory.create(SupplyChainFinance.Order_Number, ipfsHash);
}
//# sourceMappingURL=19_deploy_supplychainfinance.js.map