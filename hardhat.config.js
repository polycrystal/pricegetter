/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require('@nomiclabs/hardhat-waffle');
 require('dotenv').config()
 require("solidity-coverage");
 require("@nomiclabs/hardhat-etherscan");
 require("@nomiclabs/hardhat-solhint");
 
 const { getContractFactory } = require('@nomiclabs/hardhat-ethers/types');
 // const { ethers } = require('hardhat');
 
 
 const chainIds = {
   hardhat: 31337,
 };
 /////////////////////////////////////////////////////////////////
 /// Ensure that we have all the environment variables we need.///
 /////////////////////////////////////////////////////////////////
 
 //Deployer Info
 const mnemonic = process.env.MNEMONIC;
 if (!mnemonic) {
   throw new Error("Please set your MNEMONIC in a .env file");
 }
 const myPrivateKey = process.env.PRIVATE_KEY;
 if (!myPrivateKey) {
   throw new Error("Please set your PRIVATE_KEY in a .env file");
 }
 
 //NODE ENDPOINTS 
 const archiveMainnetNodeURL = process.env.SPEEDY_ARCHIVE_RPC;
 if (!archiveMainnetNodeURL) {
   throw new Error("Please set your  SPEEDY_ARCHIVE_RPC in a .env file, ensuring it's for the relevant blockchain");
 }
 const polygonMainnetNodeURL = process.env.POLYGON_PRIVATE_RPC;
 if (!polygonMainnetNodeURL) {
   throw new Error("Please set your POLYGON_PRIVATE_RPC in a .env file");
 }
 const bscMainnetNodeURL = process.env.BNB_PRIVATE_RPC;
 if (!bscMainnetNodeURL) {
   throw new Error("Please set your BNB_PRIVATE_RPC in a .env file")
 }
 const cronosMainnetNodeURL = process.env.CRONOS_PRIVATE_RPC;
 if (!cronosMainnetNodeURL) {
   throw new Error("Please set your CRONOS_PRIVATE_RPC in a .env file")
 }
 //API Keys
 const polygonScanApiKey = process.env.POLYGONSCAN_API_KEY;
 if (!polygonScanApiKey) {
   throw new Error("Please set your POLYGONSCAN_API_KEY in a .env file");
 }
 const bscScanApiKey = process.env.BSCSCAN_API_KEY;
 if (!bscScanApiKey) {
   throw new Error("Please set your BSCSCAN_API_KEY in a .env file");
 }
 const cronoScanApiKey = process.env.CRONOSCAN_API_KEY;
 if (!cronoScanApiKey) {
   throw new Error("Please set your CRONOSCAN_API_KEY in a .env file");
 }
 
//TASKS
task("deployPriceGetter","Deploy PriceGetter")
 .setAction(async() => {

  const AmmInfoBSC = await ethers.getContractFactory("AMMInfoBSC");
  const ammInfoBsc = await AmmInfoBSC.deploy();

  console.log("AmmInfo deployed at Address:", ammInfoBsc.address)

  const PriceGetter = await ethers.getContractFactory("BSCPriceGetter");
  const priceGetter = await PriceGetter.deploy(ammInfoBsc.address);

  console.log("PriceGetter deployed at Address:", priceGetter.address)
  
 })


 module.exports = {
   defaultNetwork: "hardhat",
   networks: {
     hardhat: {
       initialBaseFeePerGas: 1_00_000_000,
       gasPrice: "auto",
       allowUnlimitedContractSize: true,
       accounts: {
         initialIndex: 0,
         count: 20,
         mnemonic,
         path: "m/44'/60'/0'/0",
         accountsBalance: "10000000000000000000000",
       },
       forking: {
         url: archiveMainnetNodeURL,
         blockNumber: 25326200,
       },
       chainId: chainIds.hardhat,
       hardfork: "london",
     },
     polygon: {
       url: polygonMainnetNodeURL,
       accounts: [`0x${myPrivateKey}`],
     },
     bsc: {
       url: bscMainnetNodeURL,
       accounts: [`0x${myPrivateKey}`], 
     },
     cronos: {
       url: cronosMainnetNodeURL,
       accounts: [`0x${myPrivateKey}`],
     }
   },
   solidity: {
   compilers: [{
     version: "0.8.13",
     settings: {
       viaIR: true,
       optimizer: {
       enabled: true,
       runs: 1000000,
       details: {
         peephole: true,
         inliner: true,
         jumpdestRemover: true,
         orderLiterals: true,
         deduplicate: true,
         cse: true,
         constantOptimizer: true,
         yul: true
       }
       },
     },
   }],
   overrides: {
     "contracts/VaultHealer.sol": {
       version: "0.8.13",
       settings: {
         viaIR: true,
         optimizer: {
         enabled: true,
         runs: 1,
         details: {
           peephole: true,
           inliner: true,
           jumpdestRemover: true,
           orderLiterals: true,
           deduplicate: true,
           cse: true,
           constantOptimizer: true,
           yul: true
         }
         },
       },
     }
   },
   },
   mocha: {
     timeout: 90000,
   },
   etherscan: {
   apiKey: {
     polygon: polygonScanApiKey,
     bsc: bscScanApiKey,
     //cronos: cronoScanApiKey
   }
   }
 };
 
 
 