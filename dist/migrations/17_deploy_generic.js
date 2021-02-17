"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const GenericRegistry = artifacts.require('GenericRegistry');
const GenericFactory = artifacts.require('GenericFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('GENERIC')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/genericstatemachine/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, GenericRegistry, GenericFactory, [AdminRoleRegistry], uiDefinitions, storeIpfsHash);
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
async function createGeneric(factory, generic) {
    const ipfsHash = await enteth_migration_utils_1.storeIpfsJsonData({
        place: generic.place,
        type: generic.type,
        creationDate: generic.creationDate,
        optionalParameter: generic.optionalParameter,
    });
    await factory.create(generic.param1, generic.param2, generic.param3, ipfsHash);
}
//# sourceMappingURL=17_deploy_generic.js.map