"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const dayjs_1 = __importDefault(require("dayjs"));
const GateKeeper = artifacts.require('GateKeeper');
// BillOfLading
const BillOfLadingRegistry = artifacts.require('BillOfLadingRegistry');
const BillOfLading = artifacts.require('BillOfLading');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry = artifacts.require('UserRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { storeIpfsHash, enabledFeatures } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('BILLOFLADING')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/billoflading/UIDefinitions.json');
        await enteth_migration_utils_1.deployFiniteStateMachineSystem(deployer, accounts, GateKeeper, BillOfLading, BillOfLadingRegistry, [AdminRoleRegistry, UserRoleRegistry], uiDefinitions);
        const dBillOfLading = await BillOfLading.deployed();
        const dGateKeeper = await GateKeeper.deployed();
        const allRoles = await dBillOfLading.allRoles();
        for (const role of allRoles) {
            await dGateKeeper.createPermission(accounts[0], dBillOfLading.address, role, accounts[0]);
        }
        const billofladings = [
            {
                typeOfBill: 'straight',
                from: 'Wilmar International Ltd',
                to: 'Cargill',
                carrier: '0xe1a42ac93ac8f449c0b4191770e9ce521a999bad',
                portOfOrigin: 'Singapore',
                portOfDestination: 'Antwerp',
                dateOfLoading: dayjs_1.default('2019-06-24').unix(),
                typeOfGoods: 'bulk',
                valueOfGoods: '3000000 SDG',
                countOfGoods: `20`,
                weightOfGoods: `34000 kg`,
                sizeOfGoods: `4000 m3`,
                specialConditions: '',
                commercialInvoice: 'QmfNo67h6XGX162cwSSgBXVdxh6TqJDM42nrWxrCLYadMd',
                packagingList: 'QmUF8Ehv5REwdJSE64Cp379vRhnVqH7yxUE67vhxUVmevT',
                certificateOfOrigin: 'QmV5XciCpvSx51JjavfKj9PYp9dBsLAXGziSheh34qUDA9',
                letterOfInstruction: 'Qmbm8KEr6CnqUGv6wFsN6SPSx1bb4gz2reMfmwXHtjGPTz',
                dangerousGoodsForm: 'QmSYpE8cSn52n9N965n61DFPC3SPTRr8q5uiwaPSYAQqXb',
            },
        ];
        for (const billoflading of billofladings) {
            await createBillOfLading(dBillOfLading, billoflading);
        }
    }
};
async function createBillOfLading(billofladingInstance, billofladingData) {
    const ipfsHash = await storeIpfsHash(billofladingData); // warning, this only works because there are no fields not part of the ipfs data
    await billofladingInstance.create(ipfsHash);
}
//# sourceMappingURL=12_deploy_billoflading.js.map