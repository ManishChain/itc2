"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const KnowYourBusinessRegistry = artifacts.require('KnowYourBusinessRegistry');
const KnowYourBusinessFactory = artifacts.require('KnowYourBusinessFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const RequesterRoleRegistry = artifacts.require('RequesterRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('KYB')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/knowyourbusiness/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, KnowYourBusinessRegistry, KnowYourBusinessFactory, [AdminRoleRegistry, RequesterRoleRegistry], uiDefinitions, storeIpfsHash);
        const KnowYourBusinesss = [
            {
                Name: 'Good_Business',
                Address: 'Street-1',
                Products: 'Premium_Products',
                Year_of_Incorporation: '1995',
                Registration_Number: '554848',
                Contact_Details: 'abc@mail.com',
            },
        ];
        for (const KnowYourBusiness of KnowYourBusinesss) {
            await createKnowYourBusiness(factory, KnowYourBusiness);
        }
    }
};
async function createKnowYourBusiness(factory, KnowYourBusiness) {
    const ipfsHash = await enteth_migration_utils_1.storeIpfsJsonData({
        Address: KnowYourBusiness.Address,
        Products: KnowYourBusiness.Products,
        Year_of_Incorporation: KnowYourBusiness.Year_of_Incorporation,
        Registration_Number: KnowYourBusiness.Registration_Number,
        Contact_Details: KnowYourBusiness.Contact_Details,
    });
    await factory.create(KnowYourBusiness.Name, ipfsHash);
}
//# sourceMappingURL=20_deploy_kyb.js.map