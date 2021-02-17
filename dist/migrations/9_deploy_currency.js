"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const Currency = artifacts.require('Currency');
const CurrencyFactory = artifacts.require('CurrencyFactory');
const CurrencyRegistry = artifacts.require('CurrencyRegistry');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry = artifacts.require('UserRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
const found = (features) => enabledFeatures().some((feature) => features.includes(feature));
module.exports = async (deployer, network, accounts) => {
    if (found(['CURRENCY', 'BONDS'])) {
        const dGateKeeper = await GateKeeper.deployed();
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/currency/UIDefinitions.json');
        await enteth_migration_utils_1.deployERC20TokenSystem({
            gatekeeper: dGateKeeper,
            registry: { contract: CurrencyRegistry, extraParams: [] },
            factory: { contract: CurrencyFactory, extraParams: [] },
            token: {
                contract: Currency,
                instances: [
                    {
                        name: 'Euro',
                        decimals: 2,
                        extraParams: [],
                        issuance: [
                            {
                                recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                                amount: 10000,
                            },
                        ],
                    },
                    {
                        name: 'Dollar',
                        decimals: 2,
                        extraParams: [],
                        issuance: [
                            {
                                recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                                amount: 5000,
                            },
                        ],
                    },
                ],
            },
            roles: [AdminRoleRegistry],
        }, accounts[0], uiDefinitions, deployer, storeIpfsHash);
    }
};
//# sourceMappingURL=9_deploy_currency.js.map