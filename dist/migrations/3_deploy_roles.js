"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const enteth_migration_utils_1 = require("@settlemint/enteth-migration-utils");
const faker_1 = __importDefault(require("faker"));
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { enabledFeatures } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
const GateKeeper = artifacts.require('GateKeeper');
const AdminRoleRegistry = artifacts.require('AdminRoleRegistry');
const MakerRoleRegistry = artifacts.require('MakerRoleRegistry');
const CheckerRoleRegistry = artifacts.require('CheckerRoleRegistry');
const ManufacturerRoleRegistry = artifacts.require('ManufacturerRoleRegistry');
const ResellerRoleRegistry = artifacts.require('ResellerRoleRegistry');
const UserRoleRegistry = artifacts.require('UserRoleRegistry');
const RevisorRoleRegistry = artifacts.require('RevisorRoleRegistry');
const PharmacyRoleRegistry = artifacts.require('PharmacyRoleRegistry');
const AgentRoleRegistry = artifacts.require('AgentRoleRegistry');
const RegulatorRoleRegistry = artifacts.require('RegulatorRoleRegistry');
const LandRegistrarRoleRegistry = artifacts.require('LandRegistrarRoleRegistry');
const CaptainRoleRegistry = artifacts.require('CaptainRoleRegistry');
const CarrierRoleRegistry = artifacts.require('CarrierRoleRegistry');
const BusinessUnitRoleRegistry = artifacts.require('BusinessUnitRoleRegistry');
const SupplierRoleRegistry = artifacts.require('SupplierRoleRegistry');
const SSCRoleRegistry = artifacts.require('SSCRoleRegistry');
const NotaryRoleRegistry = artifacts.require('NotaryRoleRegistry');
const BuyerRoleRegistry = artifacts.require('BuyerRoleRegistry');
const RequesterRoleRegistry = artifacts.require('RequesterRoleRegistry');
const ApproverRoleRegistry = artifacts.require('ApproverRoleRegistry');
const TransporterRoleRegistry = artifacts.require('TransporterRoleRegistry');
const WarehouseRoleRegistry = artifacts.require('WarehouseRoleRegistry');
const BankRoleRegistry = artifacts.require('BankRoleRegistry');
const ApplicantRoleRegistry = artifacts.require('ApplicantRoleRegistry');
const BeneficiaryRoleRegistry = artifacts.require('BeneficiaryRoleRegistry');
const FreightForwarderRoleRegistry = artifacts.require('FreightForwarderRoleRegistry');
const roleRegistries = [];
const found = (features) => enabledFeatures().some((feature) => features.includes(feature));
if (found([
    'LOANS',
    'SHARES',
    'CURRENCY',
    'LOYALTYPOINT',
    'IDENTITIES',
    'BONDS',
    'VEHICLE',
    'EXPENSE',
    'STATEFULBONDS',
    'STATEFULOMNIBUSBONDS',
    'BILLOFLADING',
    'KYC',
])) {
    roleRegistries.push({
        registry: UserRoleRegistry,
        role: 'ROLE_USER',
        prefix: 'user',
        seed: 'valve yard cement detect festival tragic annual dinner enforce gate sun near',
    });
}
if (found(['STATEFULBONDS', 'STATEFULOMNIBUSBONDS'])) {
    roleRegistries.push({
        registry: MakerRoleRegistry,
        role: 'ROLE_MAKER',
        prefix: 'maker',
        seed: 'stove water train uniform minute juice mirror kitten human garage chunk tomato',
    }, {
        registry: CheckerRoleRegistry,
        role: 'ROLE_CHECKER',
        prefix: 'checker',
        seed: 'smile tomato cabin giraffe swallow school weapon expose tissue kitten they ribbon',
    });
}
if (found(['BILLOFLADING'])) {
    roleRegistries.push({
        registry: CaptainRoleRegistry,
        role: 'ROLE_CAPTAIN',
        prefix: 'captain',
        seed: 'spring profit rebuild kit river stove august tilt arrow crater rural tool',
    }, {
        registry: CarrierRoleRegistry,
        role: 'ROLE_CARRIER',
        prefix: 'carrier',
        seed: 'force sniff virus side pilot eyebrow fragile auto scene party degree expire',
    }, {
        registry: FreightForwarderRoleRegistry,
        role: 'ROLE_FREIGHT_FORWARDER',
        prefix: 'freightforwarder',
        seed: 'present sunset corn tower banner jump snow scrub style prize casual ball',
    });
}
if (found(['DRUGPACKAGE', 'VEHICLE'])) {
    roleRegistries.push({
        registry: ManufacturerRoleRegistry,
        role: 'ROLE_MANUFACTURER',
        prefix: 'manufacturer',
        seed: 'infant transfer spatial warfare chief mandate ahead execute grit vessel domain clay',
    });
}
if (found(['DRUGPACKAGE'])) {
    roleRegistries.push({
        registry: ResellerRoleRegistry,
        role: 'ROLE_RESELLER',
        prefix: 'reseller',
        seed: 'elder pass group bacon equal adapt fish birth search goose garage slush',
    }, {
        registry: PharmacyRoleRegistry,
        role: 'ROLE_PHARMACY',
        prefix: 'pharmacy',
        seed: 'buzz truth attend treat spring sort unaware easily fiber half load wait',
    });
}
if (found(['EXPENSES'])) {
    roleRegistries.push({
        registry: RevisorRoleRegistry,
        role: 'ROLE_REVISOR',
        prefix: 'revisor',
        seed: 'vibrant breeze axis dove diagram rescue surge ceiling day stool heart oak',
    });
}
if (found(['PLOTS'])) {
    roleRegistries.push({
        registry: LandRegistrarRoleRegistry,
        role: 'ROLE_LAND_REGISTRAR',
        prefix: 'land_registrar',
        seed: 'adapt survey million real search bargain excuse magic lab convince drum control',
    }, {
        registry: NotaryRoleRegistry,
        role: 'ROLE_NOTARY',
        prefix: 'notary',
        seed: 'bubble viable artefact lake copper sell tribe scale estate equal cube limb',
    });
}
if (found(['ORDERS'])) {
    roleRegistries.push({
        registry: BusinessUnitRoleRegistry,
        role: 'ROLE_BU',
        prefix: 'bu',
        seed: 'say radar original jungle camera position nominee assault pledge sure anger sample',
    }, {
        registry: SupplierRoleRegistry,
        role: 'ROLE_SUPPLIER',
        prefix: 'supplier',
        seed: 'infant transfer spatial warfare chief mandate ahead execute grit vessel domain clay',
    }, {
        registry: SSCRoleRegistry,
        role: 'ROLE_SSC',
        prefix: 'ssc',
        seed: 'elder pass group bacon equal adapt fish birth search goose garage slush',
    });
}
if (found(['VEHICLE'])) {
    roleRegistries.push({
        registry: AgentRoleRegistry,
        role: 'ROLE_AGENT',
        prefix: 'agent',
        seed: 'best parrot quantum thank initial toward remind broken recycle scrap deputy battle',
    }, {
        registry: RegulatorRoleRegistry,
        role: 'ROLE_REGULATOR',
        prefix: 'regulator',
        seed: 'evil raven habit style film brand change winter upon toilet dignity burger',
    });
}
if (found(['SUPPLYCHAIN', 'SUPPLYFINANCE'])) {
    roleRegistries.push({
        registry: BuyerRoleRegistry,
        role: 'ROLE_BUYER',
        prefix: 'buyer',
        seed: 'neutral oppose tail phone elegant eye jar catch awake indoor poet exile',
    }, {
        registry: SupplierRoleRegistry,
        role: 'ROLE_SUPPLIER',
        prefix: 'supplier',
        seed: 'minor hybrid vault recall cruel appear claw fury matter shift swallow glide',
    }, {
        registry: TransporterRoleRegistry,
        role: 'ROLE_TRANSPORTER',
        prefix: 'transporter',
        seed: 'destroy popular link merge unusual cram cousin joke struggle evil gauge marriage',
    }, {
        registry: WarehouseRoleRegistry,
        role: 'ROLE_WAREHOUSE',
        prefix: 'warehouse',
        seed: 'noodle earth hand wood regret section multiply spawn injury cup push sing',
    }, {
        registry: RegulatorRoleRegistry,
        role: 'ROLE_REGULATOR',
        prefix: 'regulator',
        seed: 'tackle vehicle garage wage space actor only skin reunion veteran legal ahead',
    }, {
        registry: BankRoleRegistry,
        role: 'ROLE_BANK',
        prefix: 'bank',
        seed: 'kitten elite dwarf mystery crane tragic ramp review mushroom actual maze priority',
    });
}
if (found(['KYB', 'KYC'])) {
    roleRegistries.push({
        registry: RequesterRoleRegistry,
        role: 'ROLE_REQUESTER',
        prefix: 'requester',
        seed: 'wrap bulb fold snap ready win announce swarm hidden enter innocent window',
    }, {
        registry: ApproverRoleRegistry,
        role: 'ROLE_APPROVER',
        prefix: 'approver',
        seed: 'wise output protect whale dial trap frame gauge globe hazard pride pretty',
    });
}
if (found(['BG'])) {
    roleRegistries.push({
        registry: BeneficiaryRoleRegistry,
        role: 'ROLE_BENEFICIARY',
        prefix: 'beneficiary',
        seed: 'wrap bulb fold snap ready win announce swarm hidden enter innocent window',
    }, {
        registry: ApplicantRoleRegistry,
        role: 'ROLE_APPLICANT',
        prefix: 'applicant',
        seed: 'wise output protect whale dial trap frame gauge globe hazard pride pretty',
    }, {
        registry: BankRoleRegistry,
        role: 'ROLE_BANK',
        prefix: 'bank',
        seed: 'wrap bulb fold snap ready win announce swarm hidden enter innocent window',
    });
}
module.exports = async (deployer, network, accounts) => {
    const userData = [];
    let bipIndex = 0;
    const dGateKeeper = await GateKeeper.deployed();
    // Admin
    const dAdminRoleRegistry = await enteth_migration_utils_1.deployRoleRegistry(AdminRoleRegistry, dGateKeeper, accounts[0], deployer);
    const hasRole = await dAdminRoleRegistry.hasRole(accounts[0]);
    if (!hasRole) {
        await dAdminRoleRegistry.designate(accounts[0]);
    }
    // admin key
    const adminKeyAsBytes32 = web3.utils.fromAscii('ROLE_ADMIN');
    const adminZeroPaddedKey = web3.eth.abi.encodeParameter('bytes32', adminKeyAsBytes32);
    // add roleregistry to gatekeeper and roleregistrymap
    await dGateKeeper.addRoleRegistry(dAdminRoleRegistry.address);
    await dGateKeeper.setRoleRegistryAddress(adminZeroPaddedKey, dAdminRoleRegistry.address);
    // Give to role registry the permission to designate admin roles to others
    await enteth_migration_utils_1.grantPermission(dGateKeeper, dAdminRoleRegistry, 'DESIGNATE_ROLE', dAdminRoleRegistry.address);
    for (const roleRegistry of roleRegistries) {
        const dRoleRegistry = await enteth_migration_utils_1.deployRoleRegistry(roleRegistry.registry, dGateKeeper, accounts[0], // only admin can do this
        deployer);
        const amount = 2;
        for (let i = 0; i < amount; i++) {
            userData.push({
                mnemonic: roleRegistry.seed,
                bip39Path: `m/44'/60'/0'/0/${bipIndex++}`,
                username: `${roleRegistry.prefix}${i}@example.com`,
                firstname: faker_1.default.name.firstName(),
                lastname: `(${roleRegistry.role.replace('ROLE_', '').replace('_ROLE', '')})`,
                company: faker_1.default.company.companyName(),
                password: 'settlemint',
                role: 'USER',
                roleRegistry: dRoleRegistry,
            });
        }
        // create keys again
        const keyAsBytes32 = web3.utils.fromAscii(roleRegistry.role);
        const zeroPaddedKey = web3.eth.abi.encodeParameter('bytes32', keyAsBytes32);
        // Add roleregistry to gatekeeper and roleregistrymap
        await dGateKeeper.addRoleRegistry(dRoleRegistry.address);
        await dGateKeeper.setRoleRegistryAddress(zeroPaddedKey, dRoleRegistry.address);
        // Give to role registry the permission to designate role registry roles to others
        await enteth_migration_utils_1.grantPermission(dGateKeeper, dRoleRegistry, 'DESIGNATE_ROLE', dRoleRegistry.address);
    }
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { entethMiddleware } = require('../../truffle-config.js'); // two dirs up, because it is compiled into ./dist/migrations
    await enteth_migration_utils_1.createMintAccounts({
        userData,
        mintHost: entethMiddleware,
    });
};
//# sourceMappingURL=3_deploy_roles.js.map