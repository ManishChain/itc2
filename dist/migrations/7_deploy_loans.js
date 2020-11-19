"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const Loan = artifacts.require('Loan');
const LoanFactory = artifacts.require('LoanFactory');
const LoanRegistry = artifacts.require('LoanRegistry');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry = artifacts.require('UserRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('LOANS')) {
        const dGateKeeper = await GateKeeper.deployed();
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/loan/UIDefinitions.json');
        await enteth_migration_utils_1.deployERC20TokenSystem({
            gatekeeper: dGateKeeper,
            registry: { contract: LoanRegistry, extraParams: [] },
            factory: { contract: LoanFactory, extraParams: [] },
            token: {
                contract: Loan,
                instances: [
                    {
                        name: 'Personal loans',
                        decimals: 2,
                        extraParams: [],
                        issuance: [
                            {
                                recipientGroups: [AdminRoleRegistry, UserRoleRegistry],
                                amount: 500,
                            },
                        ],
                    },
                ],
            },
            roles: [AdminRoleRegistry],
        }, accounts[0], uiDefinitions, deployer, storeIpfsHash);
    }
};
//# sourceMappingURL=7_deploy_loans.js.map