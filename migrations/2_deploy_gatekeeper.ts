import { GateKeeperContract } from '../types/truffle-contracts/GateKeeper';

const GateKeeper: GateKeeperContract = artifacts.require('GateKeeper.sol');

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => deployer.deploy(GateKeeper);
