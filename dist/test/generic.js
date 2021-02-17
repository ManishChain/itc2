"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const GenericFactory = artifacts.require('GenericFactory');
const GenericRegistry = artifacts.require('GenericRegistry');
contract('Generic', (accounts) => {
    let gateKeeper;
    let genericFactory;
    let genericRegistry;
    before(async function () {
        gateKeeper = await GateKeeper.new();
        genericRegistry = await GenericRegistry.new(gateKeeper.address);
        await enteth_migration_utils_1.createPermission(gateKeeper, genericRegistry, 'INSERT_STATEMACHINE_ROLE', accounts[0], accounts[0]);
        genericFactory = await GenericFactory.new(gateKeeper.address, genericRegistry.address);
        await enteth_migration_utils_1.createPermission(gateKeeper, genericFactory, 'CREATE_STATEMACHINE_ROLE', accounts[0], accounts[0]);
        await enteth_migration_utils_1.createPermission(gateKeeper, genericFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
        await enteth_migration_utils_1.grantPermission(gateKeeper, gateKeeper, 'CREATE_PERMISSIONS_ROLE', genericFactory.address);
        await enteth_migration_utils_1.grantPermission(gateKeeper, genericRegistry, 'INSERT_STATEMACHINE_ROLE', genericFactory.address);
    });
    it('can create a new generic', async () => {
        await genericFactory.create('test', accounts[0], 5, 'QmdB3bmb8dohiWo52QQyX1huxfwod7XAYu2aBJU8pFyhQ3');
    });
});
//# sourceMappingURL=generic.js.map