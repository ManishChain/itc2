"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const SupplyChainRegistry = artifacts.require('SupplyChainRegistry');
const SupplyChainFactory = artifacts.require('SupplyChainFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const BuyerRoleRegistry = artifacts.require('BuyerRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('SUPPLYCHAIN')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/supplychain/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, SupplyChainRegistry, SupplyChainFactory, [AdminRoleRegistry, BuyerRoleRegistry], uiDefinitions, storeIpfsHash);
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
async function createSupplyChain(factory, SupplyChain) {
    const ipfsHash = await enteth_migration_utils_1.storeIpfsJsonData({
        Item_Name: SupplyChain.Item_Name,
        Quantity: SupplyChain.Quantity,
        Order_date: SupplyChain.Order_date,
        Price: SupplyChain.Price,
        Delivery_Duration: SupplyChain.Delivery_Duration,
        Delivery_Address: SupplyChain.Delivery_Address,
    });
    await factory.create(SupplyChain.Order_Number, ipfsHash);
}
//# sourceMappingURL=18_deploy_supplychain.js.map