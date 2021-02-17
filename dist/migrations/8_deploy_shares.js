"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const Share = artifacts.require('Share');
const ShareFactory = artifacts.require('ShareFactory');
const ShareRegistry = artifacts.require('ShareRegistry');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry = artifacts.require('UserRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('SHARES')) {
        const dGateKeeper = await GateKeeper.deployed();
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/share/UIDefinitions.json');
        await enteth_migration_utils_1.deployERC20TokenSystem({
            gatekeeper: dGateKeeper,
            registry: { contract: ShareRegistry, extraParams: [] },
            factory: { contract: ShareFactory, extraParams: [] },
            token: {
                contract: Share,
                instances: [
                    {
                        name: 'Apple',
                        decimals: 2,
                        extraParams: [],
                        issuance: [
                            {
                                recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                                amount: 4500,
                            },
                        ],
                    },
                ],
            },
            roles: [AdminRoleRegistry],
        }, accounts[0], uiDefinitions, deployer, storeIpfsHash);
    }
};
//# sourceMappingURL=8_deploy_shares.js.map