"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const LoyaltyPoint = artifacts.require('LoyaltyPoint');
const LoyaltyPointFactory = artifacts.require('LoyaltyPointFactory');
const LoyaltyPointRegistry = artifacts.require('LoyaltyPointRegistry');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry = artifacts.require('UserRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('LOYALTYPOINTS')) {
        const dGateKeeper = await GateKeeper.deployed();
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/loyaltypoint/UIDefinitions.json');
        await enteth_migration_utils_1.deployERC20TokenSystem({
            gatekeeper: dGateKeeper,
            registry: { contract: LoyaltyPointRegistry, extraParams: [] },
            factory: { contract: LoyaltyPointFactory, extraParams: [] },
            token: {
                contract: LoyaltyPoint,
                instances: [
                    {
                        name: 'Skywards',
                        decimals: 8,
                        extraParams: [],
                        issuance: [
                            {
                                recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                                amount: 45000,
                            },
                        ],
                    },
                    {
                        name: 'Miles and More',
                        decimals: 18,
                        extraParams: [],
                        issuance: [
                            {
                                recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                                amount: 123000,
                            },
                        ],
                    },
                ],
            },
            roles: [AdminRoleRegistry],
        }, accounts[0], uiDefinitions, deployer, storeIpfsHash);
    }
};
//# sourceMappingURL=10_deploy_loyaltypoints.js.map