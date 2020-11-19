"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const dayjs_1 = __importDefault(require("dayjs"));
const GateKeeper = artifacts.require('GateKeeper');
const DrugPackageRegistry = artifacts.require('DrugPackageRegistry');
const DrugPackageFactory = artifacts.require('DrugPackageFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const ManufacturerRoleRegistry = artifacts.require('ManufacturerRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('DRUGPACKAGE')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/drugpackage/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, DrugPackageRegistry, DrugPackageFactory, [AdminRoleRegistry, ManufacturerRoleRegistry], uiDefinitions);
        const DrugPackages = [
            {
                labellerCode: '63851',
                productCode: '501',
                packageCode: '02',
                type: 'Vaccine',
                name: 'RabAvert',
                dosageForm: 'Injection',
                labeller: 'GSK Vaccines GmbH',
                manufacturingDate: dayjs_1.default().subtract(3, 'month').unix(),
                packageDesign: 'QmfMRTV5iXVf8gf12V8wTosvHWpf3jkuDeYvEcHXLxZ69G',
            },
            {
                labellerCode: '66828',
                productCode: '0030',
                packageCode: '02',
                type: 'Human Prescription Drug',
                name: 'Gleevec',
                dosageForm: 'Tablet',
                labeller: 'Novartis Pharma Produktions GmbH',
                activeSubstance: 'Imatinib Mesylate',
                manufacturingDate: dayjs_1.default().subtract(3, 'year').unix(),
                packageDesign: 'QmQw3cFPLR57xaSg5iC7hjABZLMh2xemiskcuLMRZwwxgH',
            },
        ];
        for (const drugPackage of DrugPackages) {
            await createDrugPackage(factory, drugPackage);
        }
    }
};
async function createDrugPackage(factory, drugPackage) {
    const ipfsHash = await storeIpfsHash({
        type: drugPackage.type,
        name: drugPackage.name,
        dosageForm: drugPackage.dosageForm,
        labeller: drugPackage.labeller,
        activeSubstance: drugPackage.activeSubstance,
        manufacturingDate: drugPackage.manufacturingDate,
        packageDesign: drugPackage.packageDesign,
    });
    await factory.create(drugPackage.labellerCode, drugPackage.productCode, drugPackage.packageCode, ipfsHash);
}
//# sourceMappingURL=5_deploy_drugpackage.js.map