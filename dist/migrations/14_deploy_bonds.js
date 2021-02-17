"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const dayjs_1 = __importDefault(require("dayjs"));
const faker_1 = __importDefault(require("faker"));
const BondFactory = artifacts.require('BondFactory');
const BondRegistry = artifacts.require('BondRegistry');
const GateKeeper = artifacts.require('GateKeeper');
const CurrencyRegistry = artifacts.require('CurrencyRegistry');
const Bond = artifacts.require('Bond');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { storeIpfsHash, enabledFeatures } = require('../../truffle-config.js');
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('BONDS')) {
        const gateKeeper = await GateKeeper.deployed();
        const currencyRegistry = await CurrencyRegistry.deployed();
        const currencies = [];
        const currencyLength = await currencyRegistry.getIndexLength();
        for (let i = 0; i < currencyLength.toNumber(); i++) {
            const currency = await currencyRegistry.getByIndex(i);
            currencies.push({ value: currency[1], label: currency[0] });
        }
        // Bonds
        await deployer.deploy(BondRegistry, gateKeeper.address);
        const bondRegistry = await BondRegistry.deployed();
        await enteth_migration_utils_1.createPermission(gateKeeper, bondRegistry, 'LIST_TOKEN_ROLE', accounts[0], accounts[0]);
        await deployer.deploy(BondFactory, bondRegistry.address, gateKeeper.address);
        const bondFactory = await BondFactory.deployed();
        await enteth_migration_utils_1.createPermission(gateKeeper, bondFactory, 'CREATE_TOKEN_ROLE', accounts[0], accounts[0]);
        await enteth_migration_utils_1.grantPermission(gateKeeper, bondRegistry, 'LIST_TOKEN_ROLE', bondFactory.address);
        await enteth_migration_utils_1.grantPermission(gateKeeper, gateKeeper, 'CREATE_PERMISSIONS_ROLE', bondFactory.address);
        await enteth_migration_utils_1.createPermission(gateKeeper, bondFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
        // two dirs up, because it is compiled into ./dist/migrations
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/bonds/UIDefinitions.json');
        uiDefinitions.selectFields.parCurrency = currencies;
        const hash = await storeIpfsHash(uiDefinitions);
        await bondFactory.setUIFieldDefinitionsHash(hash);
        for (let i = 0; i < 10; i++) {
            const name = faker_1.default.company.companyName();
            const decimals = 2;
            const duration = i % 2 ? 24 : 60;
            const period = i % 2 ? 6 : 12;
            const periodString = i % 2 ? 'SEMI' : 'ANN';
            const interest = parseInt(faker_1.default.finance.amount(1, 12, 0), 10);
            const issuanceDate = i < 5 ? dayjs_1.default().subtract(3, 'year').add(i, 'month') : dayjs_1.default().add(i, 'month');
            const ipfsHash = await storeIpfsHash({
                isin: faker_1.default.finance.iban(),
                issuer: name,
            });
            const tx = await bondFactory.createToken(`BOND ${interest}% ${issuanceDate.add(duration * 4, 'week').format('YY-MM-DD')} ${periodString}`, 10 ** decimals * (parseInt(faker_1.default.finance.amount(5, 100, 0), 10) * 100), currencies[0].value, duration, interest, period, decimals, ipfsHash);
            const bondAddress = enteth_migration_utils_1.getNewAddressFromEvents(tx, 'TokenCreated');
            // tslint:disable-next-line: no-any
            const bond = await Bond.at(bondAddress);
            await bond.setIssuanceDate(issuanceDate.unix());
            if (issuanceDate.isBefore(dayjs_1.default())) {
                await bond.launch(issuanceDate.add(1, 'day').unix());
            }
            await bond.mint(accounts[0], 10 ** decimals * faker_1.default.random.number(1000));
        }
    }
};
//# sourceMappingURL=14_deploy_bonds.js.map