import { createPermission, grantPermission } from '@settlemint/enteth-migration-utils';
import { GateKeeperContract, GateKeeperInstance } from '../types/truffle-contracts/GateKeeper';
import { GenericFactoryContract, GenericFactoryInstance } from '../types/truffle-contracts/GenericFactory';
import { GenericRegistryContract, GenericRegistryInstance } from '../types/truffle-contracts/GenericRegistry';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper');
const GenericFactory: GenericFactoryContract = artifacts.require('GenericFactory');
const GenericRegistry: GenericRegistryContract = artifacts.require('GenericRegistry');

contract('Generic', (accounts) => {
  let gateKeeper: GateKeeperInstance;
  let genericFactory: GenericFactoryInstance;
  let genericRegistry: GenericRegistryInstance;

  before(async function () {
    gateKeeper = await GateKeeper.new();
    genericRegistry = await GenericRegistry.new(gateKeeper.address);
    await createPermission(gateKeeper, genericRegistry, 'INSERT_STATEMACHINE_ROLE', accounts[0], accounts[0]);
    genericFactory = await GenericFactory.new(gateKeeper.address, genericRegistry.address);
    await createPermission(gateKeeper, genericFactory, 'CREATE_STATEMACHINE_ROLE', accounts[0], accounts[0]);
    await createPermission(gateKeeper, genericFactory, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
    await grantPermission(gateKeeper, gateKeeper, 'CREATE_PERMISSIONS_ROLE', genericFactory.address);
    await grantPermission(gateKeeper, genericRegistry, 'INSERT_STATEMACHINE_ROLE', genericFactory.address);
  });

  it('can create a new generic', async () => {
    await genericFactory.create('test', accounts[0], 5, 'QmdB3bmb8dohiWo52QQyX1huxfwod7XAYu2aBJU8pFyhQ3');
  });
});
