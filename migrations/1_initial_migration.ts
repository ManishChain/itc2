import { MigrationsContract } from '../types/truffle-contracts/Migrations';

const Migrations: MigrationsContract = artifacts.require('./Migrations.sol');

module.exports = async (deployer: Truffle.Deployer, network: string, accounts: string[]) => deployer.deploy(Migrations);
