"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const dayjs_1 = __importDefault(require("dayjs"));
const GateKeeper = artifacts.require('GateKeeper');
const BankGuaranteeRegistry = artifacts.require('BankGuaranteeRegistry');
const BankGuaranteeFactory = artifacts.require('BankGuaranteeFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const BankRoleRegistry = artifacts.require('BankRoleRegistry');
const ApplicantRoleRegistry = artifacts.require('ApplicantRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('BG')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/bankguarantee/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, BankGuaranteeRegistry, BankGuaranteeFactory, [AdminRoleRegistry, BankRoleRegistry, ApplicantRoleRegistry], uiDefinitions, storeIpfsHash);
        const BankGuarantees = [
            {
                Name: 'BG-1',
                nameApplicant: 'Settlemint',
                nameBeneficiary: 'WB',
                nameIssuingBank: 'Indian Bank',
                amount: 10233,
                amountInWords: 'One zero two three three',
                currency: 'INR',
                dateIssuance: dayjs_1.default('2020-08-08').unix(),
                dateMaturity: dayjs_1.default('2020-08-08').unix(),
                dateExpiry: dayjs_1.default('2020-08-08').unix(),
                purpose: 'QmUF8Ehv5REwdJSE64Cp379vRhnVqH7yxUE67vhxUVmevT',
                jurisdiction: 'Delhi',
            },
        ];
        for (const abankGuarantee of BankGuarantees) {
            await createBankGuarantee(factory, abankGuarantee);
        }
    }
};
async function createBankGuarantee(factory, BankGuarantee) {
    const ipfsHash = await enteth_migration_utils_1.storeIpfsJsonData({
        nameApplicant: BankGuarantee.nameApplicant,
        nameBeneficiary: BankGuarantee.nameBeneficiary,
        nameIssuingBank: BankGuarantee.nameIssuingBank,
        amount: BankGuarantee.amount,
        amountInWords: BankGuarantee.amountInWords,
        currency: BankGuarantee.currency,
        dateIssuance: BankGuarantee.dateIssuance,
        dateMaturity: BankGuarantee.dateMaturity,
        dateExpiry: BankGuarantee.dateExpiry,
        purpose: BankGuarantee.purpose,
        jurisdiction: BankGuarantee.jurisdiction,
    });
    await factory.create(BankGuarantee.Name, ipfsHash);
}
//# sourceMappingURL=23_deploy_bank_guarantee.js.map