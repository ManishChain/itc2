"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const dayjs_1 = __importDefault(require("dayjs"));
const faker_1 = __importDefault(require("faker"));
const web3_1 = __importDefault(require("web3"));
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const StatefulOmnibusBondRegistry = artifacts.require('StatefulOmnibusBondRegistry');
const BondManagerRegistry = artifacts.require('BondManagerRegistry');
const StatefulOmnibusBond = artifacts.require('StatefulOmnibusBond');
const StatefulOmnibusBondFactory = artifacts.require('StatefulOmnibusBondFactory');
const BondManagerFactory = artifacts.require('BondManagerFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const MakerRoleRegistry = artifacts.require('MakerRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('STATEFULOMNIBUSBONDS')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitionsStatefulOmnibusBond = require('../../contracts/statefulomnibusbonds/UIDefinitionsSOB.json');
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitionsBondManager = require('../../contracts/statefulomnibusbonds/UIDefinitionsBondManager.json');
        const dGateKeeper = await GateKeeper.deployed();
        await deployer.deploy(StatefulOmnibusBondRegistry, dGateKeeper.address);
        const deployedSOBRegistry = await StatefulOmnibusBondRegistry.deployed();
        await deployer.deploy(BondManagerRegistry, dGateKeeper.address);
        const deployedBMRegistry = await BondManagerRegistry.deployed();
        await enteth_migration_utils_1.createPermission(dGateKeeper, deployedSOBRegistry, 'INSERT_STATEMACHINE_ROLE', accounts[0], accounts[0]);
        await enteth_migration_utils_1.createPermission(dGateKeeper, deployedBMRegistry, 'INSERT_STATEMACHINE_ROLE', accounts[0], accounts[0]);
        await deployer.deploy(BondManagerFactory, dGateKeeper.address, deployedBMRegistry.address);
        const deployedBMFactory = await BondManagerFactory.deployed();
        await enteth_migration_utils_1.createPermission(dGateKeeper, deployedBMFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
        // set the permissions on the factory
        await enteth_migration_utils_1.grantPermission(dGateKeeper, dGateKeeper, 'CREATE_PERMISSIONS_ROLE', deployedBMFactory.address);
        await enteth_migration_utils_1.grantPermission(dGateKeeper, deployedBMRegistry, 'INSERT_STATEMACHINE_ROLE', deployedBMFactory.address);
        if (Object.keys(uiDefinitionsBondManager).length) {
            const hash = storeIpfsHash
                ? await storeIpfsHash(uiDefinitionsBondManager)
                : await enteth_migration_utils_1.storeUIDefinitions(uiDefinitionsBondManager);
            await deployedBMFactory.setUIFieldDefinitionsHash(hash);
        }
        await deployer.deploy(StatefulOmnibusBondFactory, dGateKeeper.address, deployedSOBRegistry.address, deployedBMFactory.address);
        const deployedSOBFactory = await StatefulOmnibusBondFactory.deployed();
        // Give admin permission to accounts[0]
        await enteth_migration_utils_1.createPermission(dGateKeeper, deployedSOBFactory, 'CREATE_STATEMACHINE_ROLE', accounts[0], accounts[0]);
        await enteth_migration_utils_1.createPermission(dGateKeeper, deployedSOBFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
        // give permission to the SOB factory to create a BondManager
        await enteth_migration_utils_1.createPermission(dGateKeeper, deployedBMFactory, 'CREATE_STATEMACHINE_ROLE', accounts[0], deployedSOBFactory.address);
        // Set create expense permissions on the relevant role registries
        await enteth_migration_utils_1.grantPermission(dGateKeeper, deployedSOBFactory, 'CREATE_STATEMACHINE_ROLE', AdminRoleRegistry.address);
        await enteth_migration_utils_1.grantPermission(dGateKeeper, deployedSOBFactory, 'CREATE_STATEMACHINE_ROLE', MakerRoleRegistry.address);
        // set the permissions on the factory
        await enteth_migration_utils_1.grantPermission(dGateKeeper, dGateKeeper, 'CREATE_PERMISSIONS_ROLE', deployedSOBFactory.address);
        await enteth_migration_utils_1.grantPermission(dGateKeeper, deployedSOBRegistry, 'INSERT_STATEMACHINE_ROLE', deployedSOBFactory.address);
        if (Object.keys(uiDefinitionsStatefulOmnibusBond).length) {
            const hash = storeIpfsHash
                ? await storeIpfsHash(uiDefinitionsStatefulOmnibusBond)
                : await enteth_migration_utils_1.storeUIDefinitions(uiDefinitionsStatefulOmnibusBond);
            await deployedSOBFactory.setUIFieldDefinitionsHash(hash);
        }
        // deploy example contracts
        for (let i = 0; i < 3; i++) {
            const interest = (faker_1.default.random.number(15) + 1) * 100;
            const issuanceDate = dayjs_1.default();
            const duration = (i + 1) * 12;
            const maturityDate = issuanceDate.add(duration, 'month');
            const periodString = i % 2 === 0 ? 'ANN' : 'SEMI';
            const parValue = (i + 1) * 1000;
            const issuer = faker_1.default.company.companyName();
            const statefulOmnibusBond = {
                name: `BOND ${interest}% ${maturityDate.format('YY-MM-DD')} ${periodString}`,
                isin: faker_1.default.finance.iban(),
                symbol: issuer.substring(0, 4),
                frequency: periodString,
                interest,
                decimals: 2,
                issuer: issuer,
                maturityDate: maturityDate.unix(),
                issuanceDate: issuanceDate.unix(),
                currency: 'Singapore Dollar',
                parValue,
                couponValue: Math.floor((interest / 100) * parValue),
            };
            const ipfsHash = await storeIpfsHash({
                isin: statefulOmnibusBond.isin,
                issuer: statefulOmnibusBond.issuer,
                maturityDate: statefulOmnibusBond.maturityDate,
                issuanceDate: statefulOmnibusBond.issuanceDate,
                currency: 'Singapore Dollar',
            });
            const tx = await deployedSOBFactory.create(statefulOmnibusBond.name, statefulOmnibusBond.symbol, statefulOmnibusBond.parValue, statefulOmnibusBond.interest, statefulOmnibusBond.decimals, web3_1.default.utils.toHex(statefulOmnibusBond.frequency), ipfsHash);
            if (i === 0) {
                const sobAddress = enteth_migration_utils_1.getNewAddressFromEvents(tx, 'StatefulOmnibusBondCreated');
                // tslint:disable-next-line: no-any
                const sob = await StatefulOmnibusBond.at(sobAddress);
                await sob.transitionState(await sob.STATE_TO_REVIEW());
                await sob.transitionState(await sob.STATE_ACTIVE());
            }
        }
    }
};
//# sourceMappingURL=22_deploy_statefulomnibusbond.js.map