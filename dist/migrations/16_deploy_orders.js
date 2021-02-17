"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
// Orders
const OrdersRegistry = artifacts.require('OrdersRegistry');
const Orders = artifacts.require('Orders');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const BusinessUnitRoleRegistry = artifacts.require('BusinessUnitRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('ORDERS')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/orders/UIDefinitions.json');
        await enteth_migration_utils_1.deployFiniteStateMachineSystem(deployer, accounts, GateKeeper, Orders, OrdersRegistry, [AdminRoleRegistry, BusinessUnitRoleRegistry], uiDefinitions);
        const dOrders = await Orders.deployed();
        const dGateKeeper = await GateKeeper.deployed();
        const allRoles = await dOrders.allRoles();
        for (const role of allRoles) {
            await dGateKeeper.createPermission(accounts[0], dOrders.address, role, accounts[0]);
        }
        const businessUnitRoleRegistry = await BusinessUnitRoleRegistry.deployed();
        const businessunits = await businessUnitRoleRegistry.getRoleHolders();
        const Orderss = [
            {
                businessUnit: businessunits[0],
                InBoneChickenPerKg: 400,
                WokForTwoPerPackage: 200,
                FreeRangeChickenPerChicken: 34444,
                PastaSaladPerPackage: 10,
            },
            {
                businessUnit: businessunits[0],
                InBoneChickenPerKg: 40,
                WokForTwoPerPackage: 20,
                FreeRangeChickenPerChicken: 344,
                PastaSaladPerPackage: 1,
            },
            {
                businessUnit: businessunits[1],
                InBoneChickenPerKg: 0,
                WokForTwoPerPackage: 20000,
                FreeRangeChickenPerChicken: 344444,
                PastaSaladPerPackage: 1000,
            },
            {
                businessUnit: businessunits[0],
                InBoneChickenPerKg: 678,
                WokForTwoPerPackage: 901,
                FreeRangeChickenPerChicken: 2345,
                PastaSaladPerPackage: 6789,
            },
        ];
        for (const order of Orderss) {
            await createOrders(dOrders, order);
        }
    }
};
async function createOrders(ordersInstance, OrdersData) {
    const ipfsHash = await storeIpfsHash({});
    await ordersInstance.create(OrdersData.businessUnit, OrdersData.InBoneChickenPerKg, OrdersData.WokForTwoPerPackage, OrdersData.FreeRangeChickenPerChicken, OrdersData.PastaSaladPerPackage, ipfsHash);
}
//# sourceMappingURL=16_deploy_orders.js.map