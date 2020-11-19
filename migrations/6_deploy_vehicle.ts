import { deployStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { VehicleRegistryContract } from '../types/truffle-contracts/VehicleRegistry';
import { VehicleFactoryContract, VehicleFactoryInstance } from '../types/truffle-contracts/VehicleFactory';
import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { ManufacturerRoleRegistryContract } from '../types/truffle-contracts/ManufacturerRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const VehicleRegistry: VehicleRegistryContract = artifacts.require('VehicleRegistry');
const VehicleFactory: VehicleFactoryContract = artifacts.require('VehicleFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const ManufacturerRoleRegistry: ManufacturerRoleRegistryContract = artifacts.require('ManufacturerRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('VEHICLE')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/vehicle/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      VehicleRegistry,
      VehicleFactory,
      [AdminRoleRegistry, ManufacturerRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

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

async function createVehicle(
  factory: VehicleFactoryInstance,
  vehicle: {
    vin: string;
    owner: string;
    mileage: number;
    type: string;
    plateNumber: string;
    firstRegistrationDate: number;
    make: string;
    model: string;
    channel: string;
    origin: string;
    GCCPlateNumber?: string;
  }
) {
  const ipfsHash = await storeIpfsJsonData({
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
