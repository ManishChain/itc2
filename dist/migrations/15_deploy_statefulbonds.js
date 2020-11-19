"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const dayjs_1 = __importDefault(require("dayjs"));
const faker_1 = __importDefault(require("faker"));
const GateKeeper = artifacts.require('GateKeeper');
const StatefulBond = artifacts.require('StatefulBond');
const StatefulBondRegistry = artifacts.require('StatefulBondRegistry');
const StatefulBondFactory = artifacts.require('StatefulBondFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const MakerRoleRegistry = artifacts.require('MakerRoleRegistry');
const CheckerRoleRegistry = artifacts.require('CheckerRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('STATEFULBONDS')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/statefulbonds/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, StatefulBondRegistry, StatefulBondFactory, [AdminRoleRegistry, MakerRoleRegistry, CheckerRoleRegistry], uiDefinitions, storeIpfsHash);
        for (let i = 0; i < 5; i++) {
            const interest = (faker_1.default.random.number(15) + 1) * 100;
            const issuanceDate = dayjs_1.default();
            const duration = (i + 1) * 12;
            const maturityDate = issuanceDate.add(duration, 'month');
            const periodString = i % 2 === 0 ? 'ANN' : 'SEMI';
            const parValue = (i + 1) * 1000;
            const statefulBond = {
                name: `BOND ${interest}% ${maturityDate.format('YY-MM-DD')} ${periodString}`,
                isin: faker_1.default.finance.iban(),
                frequency: periodString,
                interest,
                decimals: 2,
                issuer: faker_1.default.company.companyName(),
                maturityDate: maturityDate.unix(),
                issuanceDate: issuanceDate.unix(),
                currency: 'Singapore Dollar',
                parValue,
                inFlight: i === 3 ? web3.utils.toHex('YES') : web3.utils.toHex('NO'),
                couponValue: Math.floor((interest / 100) * parValue),
            };
            const ipfsHash = await storeIpfsHash({
                isin: statefulBond.isin,
                issuer: statefulBond.issuer,
                maturityDate: statefulBond.maturityDate,
                issuanceDate: statefulBond.issuanceDate,
                currency: 'Singapore Dollar',
            });
            const tx = await factory.create(statefulBond.name, statefulBond.parValue, statefulBond.interest, statefulBond.decimals, statefulBond.inFlight, web3.utils.toHex(statefulBond.frequency), ipfsHash);
            if (i !== 4) {
                const bondAddress = enteth_migration_utils_1.getNewAddressFromEvents(tx, 'TokenCreated');
                // tslint:disable-next-line: no-any
                const bond = await StatefulBond.at(bondAddress);
                await bond.transitionState(await bond.STATE_TO_REVIEW());
                await bond.launch(dayjs_1.default().unix());
                await bond.transitionState(await bond.STATE_READY_FOR_TOKENIZATION());
                await bond.requestTokenization(faker_1.default.random.number(1000) * 100);
                await bond.transitionState(await bond.STATE_TOKENIZATION_REQUEST());
                await bond.transitionState(await bond.STATE_TOKENIZATION_APPROVED());
            }
        }
    }
};
//# sourceMappingURL=15_deploy_statefulbonds.js.map