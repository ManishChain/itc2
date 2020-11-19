"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const VehicleRegistry = artifacts.require('VehicleRegistry');
const VehicleFactory = artifacts.require('VehicleFactory');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const ManufacturerRoleRegistry = artifacts.require('ManufacturerRoleRegistry');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('VEHICLE')) {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/vehicle/UIDefinitions.json');
        const { factory } = await enteth_migration_utils_1.deployStateMachineSystem(deployer, accounts, GateKeeper, VehicleRegistry, VehicleFactory, [AdminRoleRegistry, ManufacturerRoleRegistry], uiDefinitions, storeIpfsHash);
        const Vehicles = [
            {
                vin: '5YJXCAE45GFF00001',
                owner: '0xfd79b7a0b6f8e8ab147f3a38b0542b4d52538b0e',
                mileage: 0,
                type: 'Car',
                plateNumber: '425382',
                firstRegistrationDate: 1558362520,
                make: 'Tesla',
                model: 'Model X P90D',
                channel: 'Broker',
                origin: 'GCC',
                GCCPlateNumber: 'I37921',
            },
            {
                vin: '5YJRE1A31A1P01234',
                owner: '0xa8ff056cffef6ffc662a069a69f3f3fdddb07902',
                mileage: 10000,
                type: 'Car',
                plateNumber: '123054',
                firstRegistrationDate: 1558062520,
                make: 'Tesla',
                model: 'Roadster',
                channel: 'Agent',
                origin: 'Other',
            },
        ];
        for (const vehicle of Vehicles) {
            await createVehicle(factory, vehicle);
        }
    }
};
async function createVehicle(factory, vehicle) {
    const ipfsHash = await enteth_migration_utils_1.storeIpfsJsonData({
        type: vehicle.type,
        plateNumber: vehicle.plateNumber,
        firstRegistrationDate: vehicle.firstRegistrationDate,
        make: vehicle.make,
        model: vehicle.model,
        channel: vehicle.channel,
        origin: vehicle.origin,
        GCCPlateNumber: vehicle.GCCPlateNumber,
    });
    await factory.create(vehicle.vin, vehicle.owner, vehicle.mileage, ipfsHash);
}
//# sourceMappingURL=6_deploy_vehicle.js.map