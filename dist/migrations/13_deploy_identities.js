"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const GateKeeper = artifacts.require('GateKeeper');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const UserRoleRegistry = artifacts.require('UserRoleRegistry');
const IdentityRegistry = artifacts.require('./IdentityRegistry.sol');
const Identity = artifacts.require('./Identity.sol');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { storeIpfsHash, enabledFeatures } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
module.exports = async (deployer, network, accounts) => {
    if (enabledFeatures().includes('IDENTITIES')) {
        const dGateKeeper = await GateKeeper.deployed();
        await deployer.deploy(IdentityRegistry, dGateKeeper.address);
        const dRegistry = await IdentityRegistry.deployed();
        await deployer.deploy(Identity, dGateKeeper.address);
        const dIdentity = await Identity.deployed();
        // Give UPGRADE_CONTRACT permissions to accounts[0]
        await enteth_migration_utils_1.createPermission(dGateKeeper, dRegistry, 'UPGRADE_CONTRACT', accounts[0], accounts[0]);
        await dRegistry.upgrade(dIdentity.address);
        // Give admin permission to accounts[0]
        await enteth_migration_utils_1.createPermission(dGateKeeper, dIdentity, 'MANAGE_DIGITALTWIN_ROLE', accounts[0], accounts[0]);
        for (const roleRegistry of [AdminRoleRegistry, UserRoleRegistry]) {
            await enteth_migration_utils_1.grantPermission(dGateKeeper, dIdentity, 'MANAGE_DIGITALTWIN_ROLE', roleRegistry.address);
        }
        // Give admin permission to accounts[0]
        await enteth_migration_utils_1.createPermission(dGateKeeper, dIdentity, 'UPDATE_UIFIELDDEFINITIONS_ROLE', accounts[0], accounts[0]);
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const uiDefinitions = require('../../contracts/identity/UIDefinitions.json');
        if (Object.keys(uiDefinitions).length) {
            const hash = await storeIpfsHash(uiDefinitions);
            await dIdentity.setUIFieldDefinitionsHash(hash);
        }
        const identities = [
            {
                idNumber: web3.utils.fromAscii('IN198001021112345'),
                kind: web3.utils.fromAscii('ID CARD'),
                ipfsFields: {
                    Nama_Lengkap: 'John Doe',
                    Tempat_Lahir: 'Denpasar',
                    Tanggal_Lahir: '11-11-1981',
                    Nama_Ibu_Kandung: 'Ingrid',
                    Jenis_Identitas: 'Standard',
                    Alamat_sesuai_ID: 'Main street 123',
                    Alamat_Tinggal_Sekarang: 'N/A',
                    Jenis_Kelamin: 'Male',
                    Kewarganegaraan: 'American',
                    Status_Kependudukan: 'resident',
                    NPWP: '123-456-789',
                    Status_Perkawinan: 'Married',
                    Agama: 'Catholic',
                    Pendidikan_Terakhir: 'Biology',
                    Alamat_Kirim_Surat: 'Main street 123',
                    Email: 'john.doe@outlook.com',
                    Telepon_Selular: '123456789',
                    Telepon_Rumah: '987654321',
                    Telepon_Kantor: 'N/A',
                    Nama_Perusahaan: 'BASF',
                    Pekerjaan_Sekarang: 'Process Engineer',
                    Alamat_Kantor: 'Station street 345',
                    Bidang_Usaha: 'Research',
                    Jabatan: 'Employee',
                    Divisi: 'Research',
                    Tangal_Mulai_Bekerja: '01-01-2010',
                    Status_Pekerjaan: 'Employed',
                    Sumber_Dana: '2 million rupiah',
                    Penghasilan_Rerata: '25 million rupiah',
                    Maksud_dan_Tujuan_Berhububungan_dgn_Bank: 'Loan',
                },
            },
        ];
        for (const identity of identities) {
            await createIdentity(dIdentity, identity);
        }
    }
};
async function createIdentity(identityInstance, identityData) {
    const ipfsHash = await storeIpfsHash(identityData.ipfsFields);
    await identityInstance.create(identityData.idNumber, identityData.kind, ipfsHash);
}
//# sourceMappingURL=13_deploy_identities.js.map