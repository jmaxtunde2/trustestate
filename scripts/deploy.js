const hre = require("hardhat");

async function main() {
  // Compile the contracts (optional, Hardhat usually compiles automatically)
  await hre.run("compile");

  // Get the ContractFactory for TrustEstate
  const TrustEstate = await hre.ethers.getContractFactory("TrustEstate");
  console.log("Deploying TrustEstate to Polygon Amoy...");

  // IMPORTANT: Ensure these are the actual wallet addresses on Polygon Amoy
  // These will be the initial agencyWallet and governmentWallet addresses in your contract.
  const agencyWalletAddress = "0x31808A72172d5608fCd3677A312c6d8084D86bEB"; // Your actual MetaMask address for agency
  const governmentWalletAddress = "0x3eBE13eb925Eb4f31D1a122123660343a679B2A5"; // Your actual MetaMask address for government

  // The previous 'if' condition that checked for placeholder addresses has been removed.
  // Make sure these addresses are correct and funded with Amoy MATIC.

  // Deploy the TrustEstate contract with constructor arguments
  const trustEstate = await TrustEstate.deploy(
    agencyWalletAddress,
    governmentWalletAddress
  );

  // Wait for the deployment transaction to be mined
  await trustEstate.waitForDeployment();

  // Get the deployed contract's address
  const deployedAddress = await trustEstate.getAddress();

  console.log(`TrustEstate deployed to: ${deployedAddress}`);

  // You can optionally verify the contract on Polygonscan Amoy here
  console.log("Verifying contract on Polygonscan Amoy (this may take a moment)...");
  try {
    await hre.run("verify:verify", {
      address: deployedAddress,
      constructorArguments: [
        agencyWalletAddress,
        governmentWalletAddress
      ],
    });
    console.log("Contract verified successfully!");
  } catch (error) {
    if (error.message.includes("Reason: Already Verified")) {
      console.log("Contract is already verified.");
    } else {
      console.error("Error verifying contract:", error);
    }
  }
}

// Handle errors and run the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });



// const hre = require("hardhat");

// async function main() {
//   // Compile the contracts
//   await hre.run("compile");

//   // Deploy the LandRegistry contract
//   const TrustEstate = await hre.ethers.getContractFactory("TrustEstate");
//   console.log("Deploying TrustEstate...");

//   const trustEstate = await TrustEstate.deploy();

//   // Wait for the deployment to complete
//   await trustEstate.deployed();

//   console.log(`TrustEstate deployed to: ${trustEstate.address}`);
// }

// // Handle errors and run the script
// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
