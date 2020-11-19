import { deployFiniteStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';

import {
  AdminRoleRegistryContract,
  GateKeeperContract,
  PackageContract,
  PackageInstance,
  PackageRegistryContract,
} from '../types/truffle-contracts';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');

const PackageRegistry: PackageRegistryContract = artifacts.require('PackageRegistry');
const Package: PackageContract = artifacts.require('Package');

const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('SUPPLYPACKAGE')) {
    await deployFiniteStateMachineSystem(deployer, accounts, GateKeeper, Package, PackageRegistry, [AdminRoleRegistry]);

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

async function createPackage(packageInstance: PackageInstance, packageData: IPackageData, owner: string) {
  const ipfsHash = await storeIpfsJsonData({
    name: packageData.name,
    comment: packageData.comment,
    isMedical: packageData.isMedical,
    tiltable: packageData.tiltable,
    temperatureIgnored: packageData.temperatureIgnored,
    temperatureThreshold: packageData.temperatureThreshold,
  });
  // Hiervoor evt Contract nog aanpassen
  await (packageInstance.create(
    packageData.name,
    packageData.comment,
    packageData.isMedical,
    packageData.tiltable,
    packageData.temperatureIgnored,
    packageData.temperatureThreshold,
    ipfsHash,
    owner
  ) as any)
    .on('transactionHash', (hash: string) => {
      console.log(`Creating package ${packageData.name}: ${hash}`);
    })
    .on('receipt', (receipt: any) => console.log(`Success!`));
}

interface IPackageData {
  name: string;
  comment: string;
  isMedical: boolean;
  tiltable: boolean;
  temperatureIgnored: boolean;
  temperatureThreshold: number;
}
