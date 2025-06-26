require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config(); // Load environment variables from .env file

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // --- Solidity Compiler Configuration ---
  solidity: {
    version: "0.8.28", // Updated to match your contract's pragma
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // Adjust as needed
      },
      viaIR: true, // Enable Intermediate Representation
    },
  },
  // --- Network Configurations ---
  networks: {
    hardhat: {
      // Default Hardhat network config
    },
    amoy: {
      url: process.env.POLYGON_AMOY_RPC_URL, // Your Ankr RPC for Polygon Amoy
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [], // Use your wallet's raw private key
      chainId: 80002, // Polygon Amoy testnet chain ID
    },
    // You can add other networks here if needed, e.g., sepolia
    // sepolia: {
    //   url: process.env.SEPOLIA_RPC_URL || "",
    //   accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    //   chainId: 11155111,
    // },
  },
  // --- Etherscan Verification Configuration ---
  etherscan: {
    apiKey: {
      polygonAmoy: process.env.POLYGONSCAN_API_KEY || "", // API key for Polygon Amoy verification
    },
    customChains: [
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com/"
        }
      }
    ]
  },
  // --- Gas Reporter Configuration (optional) ---
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY || "",
    token: "MATIC",
    gasPriceApi: "https://api.polygonscan.com/api?module=proxy&action=eth_gasprice",
    outputFile: "gas-report.txt",
    noColors: true,
  },
};




























// require("@nomicfoundation/hardhat-toolbox");
// require('@nomiclabs/hardhat-ethers');

// /** @type import('hardhat/config').HardhatUserConfig */
// require('dotenv').config();
// module.exports = {
//   solidity: {
//     version: "0.8.24", // Replace with your Solidity version
//     settings: {
//       optimizer: {
//         enabled: true,
//         runs: 200, // Adjust as needed
//       },
//       viaIR: true, // Enable Intermediate Representation
//     },
//   },
//   networks: {
//     amoy: {
//       url: 'https://rpc.ankr.com/polygon_amoy', // Ankr RPC for Polygon Mumbai
//       accounts: [`0x${process.env.PRIVATE_KEY}`], // Use your wallet's private key
//       chainId: 80002, // Polygon Mumbai testnet chain ID
//     },
//   },
// };
