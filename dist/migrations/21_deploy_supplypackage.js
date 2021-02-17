"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const PackageRegistry = artifacts.require('PackageRegistry');
const Package = artifacts.require('Package');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('SUPPLYPACKAGE')) {
        await enteth_migration_utils_1.deployFiniteStateMachineSystem(deployer, accounts, GateKeeper, Package, PackageRegistry, [AdminRoleRegistry]);
        const dGateKeeper = await GateKeeper.deployed();
        const dPackage = await Package.deployed();
        const allRoles = await dPackage.allRoles();
        for (const role of allRoles) {
            await dGateKeeper.createPermission(accounts[0], dPackage.address, role, accounts[0]);
        }
        const packages = [
            {
                name: 'FPP2 masks',
                comment: 'Maskers voor COVID-19 bestrijding',
                isMedical: true,
                tiltable: true,
                temperatureIgnored: true,
                temperatureThreshold: 0,
            },
            {
                name: 'Curry Ketchup',
                comment: 'Delhaize Curry Ketchup',
                isMedical: false,
                tiltable: true,
                temperatureIgnored: false,
                temperatureThreshold: 4,
            },
        ];
        for (const apackage of packages) {
            await createPackage(dPackage, apackage, accounts[0]);
        }
    }
};
async function createPackage(packageInstance, packageData, owner) {
    const ipfsHash = await enteth_migration_utils_1.storeIpfsJsonData({
        name: packageData.name,
        comment: packageData.comment,
        isMedical: packageData.isMedical,
        tiltable: packageData.tiltable,
        temperatureIgnored: packageData.temperatureIgnored,
        temperatureThreshold: packageData.temperatureThreshold,
    });
    // Hiervoor evt Contract nog aanpassen
    await packageInstance.create(packageData.name, packageData.comment, packageData.isMedical, packageData.tiltable, packageData.temperatureIgnored, packageData.temperatureThreshold, ipfsHash, owner)
        .on('transactionHash', (hash) => {
        console.log(`Creating package ${packageData.name}: ${hash}`);
    })
        .on('receipt', (receipt) => console.log(`Success!`));
}
//# sourceMappingURL=21_deploy_supplypackage.js.map