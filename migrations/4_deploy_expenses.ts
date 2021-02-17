import { deployFiniteStateMachineSystem } from '@settlemint/enteth-migration-utils';
import dayjs from 'dayjs';

import { AdminRoleRegistryContract } from '../types/truffle-contracts/AdminRoleRegistry';
import { ExpenseContract, ExpenseInstance } from '../types/truffle-contracts/Expense';
import { ExpenseRegistryContract } from '../types/truffle-contracts/ExpenseRegistry';
import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';
import { RevisorRoleRegistryContract } from '../types/truffle-contracts/RevisorRoleRegistry';
import { UserRoleRegistryContract } from '../types/truffle-contracts/UserRoleRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');

// Expense
const ExpenseRegistry: ExpenseRegistryContract = artifacts.require('ExpenseRegistry');
const Expense: ExpenseContract = artifacts.require('Expense');
const AdminRoleRegistry: AdminRoleRegistryContract = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry: UserRoleRegistryContract = artifacts.require('UserRoleRegistry');
const RevisorRoleRegistry: RevisorRoleRegistryContract = artifacts.require('RevisorRoleRegistry');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures, storeIpfsHash } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => {
  if (enabledFeatures().includes('EXPENSES')) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const uiDefinitions = require('../../contracts/expense/UIDefinitions.json');
    await deployFiniteStateMachineSystem(
      deployer,
      accounts,
      GateKeeper,
      Expense,
      ExpenseRegistry,
      [AdminRoleRegistry, UserRoleRegistry],
      uiDefinitions
    );
    const dExpense = await Expense.deployed();

    const dGateKeeper = await GateKeeper.deployed();
    const allRoles = await dExpense.allRoles();
    for (const role of allRoles) {
      await dGateKeeper.createPermission(accounts[0], dExpense.address, role, accounts[0]);
    }

    const roleToRoleRegistries = {
      ROLE_ADMIN: AdminRoleRegistry,
      ROLE_USER: UserRoleRegistry,
      ROLE_REVISOR: RevisorRoleRegistry,
    };

    for (const role of Object.keys(roleToRoleRegistries)) {
      await dGateKeeper.grantPermission(
        roleToRoleRegistries[role].address,
        dExpense.address,
        web3.eth.abi.encodeParameter('bytes32', web3.utils.fromAscii(role))
      );
    }

    const expenses = [
      {
        amount: '19829',
        proof: 'QmY9dQYk1Pm1ctcnoKCtpmFKNz6z9YpdhTqsLETEa44J1N',
        localCurrencyAmount: '129812',
        localCurrency: 'CFA',
        exchangeRate: '654.647808',
        resultAndActivity: 'R2_A1',
        category: 'running_costs',
        type: 'Meeting',
        country: 'BJ',
        settlement: 'cash',
        incomeGeneratingActivity: 'no',
        description: 'Appui alimentaire aux enfants de maman Marguerite',
        supplier: 'Gold Business Center',
        invoiceDate: dayjs('2019-03-12').unix(),
      },
    ];

    for (const expense of expenses) {
      await createExpense(dExpense, expense, accounts[0]);
    }
  }
};

async function createExpense(expenseInstance: ExpenseInstance, expenseData: IExpenseData, owner: string) {
  const ipfsHash = await storeIpfsHash({
    localCurrencyAmount: expenseData.localCurrencyAmount,
    localCurrency: expenseData.localCurrency,
    exchangeRate: expenseData.exchangeRate,
    resultAndActivity: expenseData.resultAndActivity,
    category: expenseData.category,
    country: expenseData.country,
    settlement: expenseData.settlement,
    incomeGeneratingActivity: expenseData.incomeGeneratingActivity,
    description: expenseData.description,
    supplier: expenseData.supplier,
    invoiceDate: expenseData.invoiceDate,
    type: expenseData.type,
  });

  await expenseInstance.create(expenseData.amount, expenseData.proof, expenseData.settlement, ipfsHash, owner);
}

interface IExpenseData {
  amount: string;
  proof: string;
  localCurrencyAmount: string;
  localCurrency: string;
  exchangeRate: string;
  resultAndActivity: string;
  category: string;
  type?: string;
  country: string;
  settlement: string;
  incomeGeneratingActivity: string;
  description: string;
  supplier: string;
  invoiceDate: number;
}
