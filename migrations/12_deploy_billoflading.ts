import { deployFiniteStateMachineSystem } from '@settlemint/enteth-migration-utils';
import dayjs from 'dayjs';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { BillOfLadingContract, BillOfLadingInstance } from '../types/truffle-contracts/BillOfLading';
import { BillOfLadingRegistryContract } from '../types/truffle-contracts/BillOfLadingRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { UserRoleRegistryContract } from '../types/truffle-contracts/UserRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');

// BillOfLading
const BillOfLadingRegistry: BillOfLadingRegistryContract = artifacts.require('BillOfLadingRegistry');
const BillOfLading: BillOfLadingContract = artifacts.require('BillOfLading');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry: UserRoleRegistryContract = artifacts.require('UserRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { storeIpfsHash, enabledFeatures } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('BILLOFLADING')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/billoflading/UIDefinitions.json');
    await deployFiniteStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      BillOfLading,
      BillOfLadingRegistry,
      [AdminRoleRegistry, UserRoleRegistry],
      uiDefinitions
    );
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
        dateOfLoading: dayjs('2019-06-24').unix(),
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

async function createBillOfLading(billofladingInstance: BillOfLadingInstance, billofladingData: IBillOfLadingData) {
  const ipfsHash = await storeIpfsHash(billofladingData); // warning, this only works because there are no fields not part of the ipfs data

  await billofladingInstance.create(ipfsHash);
}

interface IBillOfLadingData {
  typeOfBill: string;
  from: string;
  to: string;
  carrier: string;
  portOfOrigin: string;
  portOfDestination: string;
  dateOfLoading: number;
  typeOfGoods: string;
  valueOfGoods: string;
  countOfGoods: string;
  weightOfGoods: string;
  sizeOfGoods: string;
  specialConditions: string;
  commercialInvoice: string;
  packagingList: string;
  certificateOfOrigin: string;
  letterOfInstruction: string;
  dangerousGoodsForm: string;
}
