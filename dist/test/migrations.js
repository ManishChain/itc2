"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const Migrations = artifacts.require('Migrations');
describe('Migrations', () => {
    // let accounts: string[];
    let migrations;
    before(async function () {
        // accounts = await w3.eth.getAccounts();
        migrations = await Migrations.new();
    });
    it('Has an initial latest migration of 0', async () => {
        const lastCompletedMigration = await migrations.lastCompletedMigration();
        expect(lastCompletedMigration.toNumber()).to.be.equal(0);
    });
});
//# sourceMappingURL=migrations.js.map