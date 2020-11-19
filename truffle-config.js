require('ts-node/register')

const HDWalletProvider = require('@truffle/hdwallet-provider')
const IpfsHttpClient = require('ipfs-http-client')
const solcconfig = require('./solcconfig.json')
const Web3 = require('web3')

require('dotenv').config()

const bpaasconfig = {
  mnemonic: process.env.DEMO_MNEMONIC,
  jsonRPC: process.env.DEMO_RPCENDPOINT,
  wsRPC: process.env.DEMO_WS_RPCENDPOINT,
  ipfsHost: process.env.DEMO_IPFS_HOST || 'localhost',
  ipfsPathPrefix: process.env.DEMO_IPFS_PATH_PREFIX || '',
  ipfsProtocol: process.env.DEMO_IPFS_PROTOCOL || 'http',
  ipfsPort: process.env.DEMO_IPFS_PORT || 5001,
  entethMiddleware: process.env.DEMO_ENTETH_MIDDLEWARE,
  features:
    process.env.DEMO_FEATURES ||
    'BG,KYC,KYB,SUPPLYCHAIN,SUPPLYFINANCE,EXPENSES,DRUGPACKAGE,VEHICLE,LOANS,SHARES,CURRENCY,LOYALTYPOINTS,PLOTS,BILLOFLADING,IDENTITIES,BONDS,STATEFULBONDS,STATEFULOMNIBUSBONDS,ORDERS,GENERIC,SUPPLYPACKAGE',
}

module.exports = {
  entethMiddleware: bpaasconfig.entethMiddleware,
  storeIpfsHash: async (data) => {
    try {
      const ipfs = new IpfsHttpClient({
        host: bpaasconfig.ipfsHost,
        port: bpaasconfig.ipfsPort,
        protocol: bpaasconfig.ipfsProtocol,
        apiPath: `${bpaasconfig.ipfsPathPrefix}/api/v0/`,
        timeout: 10000, // 10 seconds
      })
      const addResult = await ipfs.add({ content: Buffer.from(JSON.stringify(data))});

      // fallback pin to infura
      const infura = IpfsHttpClient({
        host: 'ipfs.infura.io',
        port: 5001,
        protocol: 'https',
        timeout: 10000, // 10 seconds
      });
      infura.pin.addAll(addResult);

      console.log(`--> Stored a file on IPFS: ${addResult.cid.toString()}`)
      return addResult.cid.toString();
    } catch (error) {
      console.log(error)
    }
  },
  enabledFeatures: () => bpaasconfig.features.split(','),
  migrations_directory: './dist/migrations',
  networks: {
    development: {
      host: '127.0.0.1', // Localhost (default: none)
      port: 8545, // Standard Ethereum port (default: none)
      network_id: '*', // Any network (default: none)
      websockets: true, // Enable EventEmitter interface for web3 (default: false)
      gasPrice: '0',
      gas: '0x1fffffffffffff',
    },
    launchpad: {
      provider: () =>
        new HDWalletProvider(bpaasconfig.mnemonic, new Web3.providers.WebsocketProvider(bpaasconfig.wsRPC)),
      gasPrice: '0',
      network_id: '*',
      websockets: true,
      production: false,
      gas: '0x1dcd6400',
    },
  },
  compilers: {
    solc: {
      version: solcconfig.version,
      settings: {
        optimizer: solcconfig.optimizer,
        evmVersion: solcconfig.evmVersion,
      },
    },
  },
  mocha: {
    enableTimeouts: false
  },
}
