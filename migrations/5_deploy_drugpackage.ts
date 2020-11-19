import { deployStateMachineSystem } from '@settlemint/enteth-migration-utils';
import dayjs from 'dayjs';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { DrugPackageFactoryContract, DrugPackageFactoryInstance } from '../types/truffle-contracts/DrugPackageFactory';
import { DrugPackageRegistryContract } from '../types/truffle-contracts/DrugPackageRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { ManufacturerRoleRegistryContract } from '../types/truffle-contracts/ManufacturerRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const DrugPackageRegistry: DrugPackageRegistryContract = artifacts.require('DrugPackageRegistry');
const DrugPackageFactory: DrugPackageFactoryContract = artifacts.require('DrugPackageFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const ManufacturerRoleRegistry: ManufacturerRoleRegistryContract = artifacts.require('ManufacturerRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('DRUGPACKAGE')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/drugpackage/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      DrugPackageRegistry,
      DrugPackageFactory,
      [AdminRoleRegistry, ManufacturerRoleRegistry],
      uiDefinitions
    );

    const DrugPackages = [
      {
        labellerCode: '63851',
        productCode: '501',
        packageCode: '02',
        type: 'Vaccine',
        name: 'RabAvert',
        dosageForm: 'Injection',
        labeller: 'GSK Vaccines GmbH',
        manufacturingDate: dayjs().subtract(3, 'month').unix(),
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
        manufacturingDate: dayjs().subtract(3, 'year').unix(),
        packageDesign: 'QmQw3cFPLR57xaSg5iC7hjABZLMh2xemiskcuLMRZwwxgH',
      },
    ];

    for (const drugPackage of DrugPackages) {
      await createDrugPackage(factory, drugPackage);
    }
  }
};

async function createDrugPackage(
  factory: DrugPackageFactoryInstance,
  drugPackage: {
    labellerCode: string;
    productCode: string;
    packageCode: string;
    type: string;
    name: string;
    dosageForm: string;
    labeller: string;
    activeSubstance?: string;
    manufacturingDate: number;
    packageDesign: string;
  }
) {
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
