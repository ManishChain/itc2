import { deployStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';
import dayjs from 'dayjs';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import {
  KnowYourCustomerFactoryContract,
  KnowYourCustomerFactoryInstance,
} from '../types/truffle-contracts/KnowYourCustomerFactory';
import { KnowYourCustomerRegistryContract } from '../types/truffle-contracts/KnowYourCustomerRegistry';
import { RequesterRoleRegistryContract } from '../types/truffle-contracts/RequesterRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const KnowYourCustomerRegistry: KnowYourCustomerRegistryContract = artifacts.require('KnowYourCustomerRegistry');
const KnowYourCustomerFactory: KnowYourCustomerFactoryContract = artifacts.require('KnowYourCustomerFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const RequesterRoleRegistry: RequesterRoleRegistryContract = artifacts.require('RequesterRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('KYC')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/knowyourcustomer/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      KnowYourCustomerRegistry,
      KnowYourCustomerFactory,
      [AdminRoleRegistry, RequesterRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

    const KnowYourCustomers = [
      {
        Name: 'KYC-1',
        gender: 'Male',
        firstName: 'Thomas',
        middleName: 'Neo',
        lastName: 'Anderson',
        fatherName: 'Matrix',
        motherName: 'Reloaded',
        dateOfBirth: dayjs('1919-04-08').unix(),
        city: 'Delhi',
        addressLine1: 'Zion',
        addressLine2: 'Mainframe',
        addressLine3: 'Computer',
        pincode: `4000 m3`,
        miscInfo: '',
        birthCertificate: 'QmfNo67h6XGX162cwSSgBXVdxh6TqJDM42nrWxrCLYadMd',
        PAN: 'QmUF8Ehv5REwdJSE64Cp379vRhnVqH7yxUE67vhxUVmevT',
        DL: 'QmV5XciCpvSx51JjavfKj9PYp9dBsLAXGziSheh34qUDA9',
        ADHAAR: 'Qmbm8KEr6CnqUGv6wFsN6SPSx1bb4gz2reMfmwXHtjGPTz',
        passport: 'QmSYpE8cSn52n9N965n61DFPC3SPTRr8q5uiwaPSYAQqXb',
      },
    ];
    for (const KnowYourCustomer of KnowYourCustomers) {
      await createKnowYourCustomer(factory, KnowYourCustomer);
    }
  }
};

async function createKnowYourCustomer(
  factory: KnowYourCustomerFactoryInstance,
  KnowYourCustomer: {
    Name: string;
    gender: string;
    firstName: string;
    middleName: string;
    lastName: string;
    fatherName: string;
    motherName: string;
    dateOfBirth: number;
    city: string;
    addressLine1: string;
    addressLine2: string;
    addressLine3: string;
    pincode: string;
    miscInfo: string;
    birthCertificate: string;
    PAN: string;
    DL: string;
    ADHAAR: string;
    passport: string;
  }
) {
  const ipfsHash = await storeIpfsJsonData({
    gender: KnowYourCustomer.gender,
    firstName: KnowYourCustomer.firstName,
    middleName: KnowYourCustomer.middleName,
    lastName: KnowYourCustomer.lastName,
    fatherName: KnowYourCustomer.fatherName,
    motherName: KnowYourCustomer.motherName,
    dateOfBirth: KnowYourCustomer.dateOfBirth,
    city: KnowYourCustomer.city,
    addressLine1: KnowYourCustomer.addressLine1,
    addressLine2: KnowYourCustomer.addressLine2,
    addressLine3: KnowYourCustomer.addressLine3,
    pincode: KnowYourCustomer.pincode,
    miscInfo: KnowYourCustomer.miscInfo,
    birthCertificate: KnowYourCustomer.birthCertificate,
    PAN: KnowYourCustomer.PAN,
    DL: KnowYourCustomer.DL,
    ADHAAR: KnowYourCustomer.ADHAAR,
    passport: KnowYourCustomer.passport,
  });
  await factory.create(KnowYourCustomer.Name, ipfsHash);
}
