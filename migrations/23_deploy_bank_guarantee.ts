import { deployStateMachineSystem, storeIpfsJsonData } from '@settlemint/enteth-migration-utils';
import dayjs from 'dayjs';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import {
  BankGuaranteeFactoryContract,
  BankGuaranteeFactoryInstance,
} from '../types/truffle-contracts/BankGuaranteeFactory';
import { BankGuaranteeRegistryContract } from '../types/truffle-contracts/BankGuaranteeRegistry';

import { BankRoleRegistryContract } from '../types/truffle-contracts/BankRoleRegistry';
import { ApplicantRoleRegistryContract } from '../types/truffle-contracts/ApplicantRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const BankGuaranteeRegistry: BankGuaranteeRegistryContract = artifacts.require('BankGuaranteeRegistry');
const BankGuaranteeFactory: BankGuaranteeFactoryContract = artifacts.require('BankGuaranteeFactory');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');

const BankRoleRegistry: BankRoleRegistryContract = artifacts.require('BankRoleRegistry');
const ApplicantRoleRegistry: ApplicantRoleRegistryContract = artifacts.require('ApplicantRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('BG')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/bankguarantee/UIDefinitions.json');

    const { factory } = await deployStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      BankGuaranteeRegistry,
      BankGuaranteeFactory,
      [AdminRoleRegistry, BankRoleRegistry, ApplicantRoleRegistry],
      uiDefinitions,
      storeIpfsHash
    );

    const BankGuarantees = [
      {
        Name: 'BG-1',
        nameApplicant: 'Settlemint',
        nameBeneficiary: 'WB',
        nameIssuingBank: 'Indian Bank',
        amount: 10233,
        amountInWords: 'One zero two three three',
        currency: 'INR',
        dateIssuance: dayjs('2020-08-08').unix(),
        dateMaturity: dayjs('2020-08-08').unix(),
        dateExpiry: dayjs('2020-08-08').unix(),
        purpose: 'QmUF8Ehv5REwdJSE64Cp379vRhnVqH7yxUE67vhxUVmevT',
        jurisdiction: 'Delhi',
      },
    ];
    for (const abankGuarantee of BankGuarantees) {
      await createBankGuarantee(factory, abankGuarantee);
    }
  }
};

async function createBankGuarantee(
  factory: BankGuaranteeFactoryInstance,
  BankGuarantee: {
    Name: string;
    nameApplicant: string;
    nameBeneficiary: string;
    nameIssuingBank: string;
    amount: number;
    amountInWords: string;
    currency: string;
    dateIssuance: number;
    dateMaturity: number;
    dateExpiry: number;
    purpose: string;
    jurisdiction: string;
  }
) {
  const ipfsHash = await storeIpfsJsonData({
    nameApplicant: BankGuarantee.nameApplicant,
    nameBeneficiary: BankGuarantee.nameBeneficiary,
    nameIssuingBank: BankGuarantee.nameIssuingBank,
    amount: BankGuarantee.amount,
    amountInWords: BankGuarantee.amountInWords,
    currency: BankGuarantee.currency,
    dateIssuance: BankGuarantee.dateIssuance,
    dateMaturity: BankGuarantee.dateMaturity,
    dateExpiry: BankGuarantee.dateExpiry,
    purpose: BankGuarantee.purpose,
    jurisdiction: BankGuarantee.jurisdiction,
  });
  await factory.create(BankGuarantee.Name, ipfsHash);
}
