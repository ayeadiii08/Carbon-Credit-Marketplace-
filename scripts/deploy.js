const hre = require("hardhat");

async function main() {
  console.log("🌱 Deploying Carbon Credit Marketplace to Core Testnet 2...\n");

  // Get the ContractFactory and Signers
  const [deployer] = await hre.ethers.getSigners();
  
  console.log("📝 Deployment Details:");
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", hre.ethers.utils.formatEther(await deployer.getBalance()), "CORE");
  console.log("Network:", hre.network.name);
  console.log("Chain ID:", hre.network.config.chainId);
  console.log("RPC URL:", hre.network.config.url);
  console.log("─".repeat(50));

  try {
    // Deploy the contract
    console.log("🚀 Starting deployment...");
    const CarbonCreditMarketplace = await hre.ethers.getContractFactory("CarbonCreditMarketplace");
    
    console.log("📦 Deploying contract...");
    const marketplace = await CarbonCreditMarketplace.deploy();

    console.log("⏳ Waiting for deployment confirmation...");
    await marketplace.deployed();

    console.log("✅ Contract deployed successfully!");
    console.log("Contract Address:", marketplace.address);
    console.log("Transaction Hash:", marketplace.deployTransaction.hash);
    console.log("Block Number:", marketplace.deployTransaction.blockNumber);

    // Wait for a few confirmations
    console.log("⏳ Waiting for block confirmations...");
    const receipt = await marketplace.deployTransaction.wait(3);
    
    console.log("✅ Deployment confirmed!");
    console.log("Gas Used:", receipt.gasUsed.toString());
    console.log("Gas Price:", hre.ethers.utils.formatUnits(receipt.effectiveGasPrice, "gwei"), "gwei");
    
    // Calculate deployment cost
    const deploymentCost = receipt.gasUsed.mul(receipt.effectiveGasPrice);
    console.log("💰 Deployment Cost:", hre.ethers.utils.formatEther(deploymentCost), "CORE");

    console.log("\n" + "=".repeat(60));
    console.log("🎉 DEPLOYMENT SUMMARY");
    console.log("=".repeat(60));
    console.log("📍 Network: Core Testnet 2");
    console.log("📝 Contract: CarbonCreditMarketplace");
    console.log("📍 Address:", marketplace.address);
    console.log("👤 Deployer:", deployer.address);
    console.log("🔗 Transaction:", marketplace.deployTransaction.hash);
    console.log("⛽ Gas Used:", receipt.gasUsed.toString());
    console.log("💰 Cost:", hre.ethers.utils.formatEther(deploymentCost), "CORE");
    console.log("=".repeat(60));

    // Test basic functionality
    console.log("\n🧪 Testing basic contract functionality...");
    
    try {
      const stats = await marketplace.getMarketplaceStats();
      console.log("✅ Contract is responsive");
      console.log("📊 Initial Stats - Total Listed:", stats.totalListed.toString(), "| Total Sold:", stats.totalSold.toString());
      
      const owner = await marketplace.owner();
      console.log("👤 Contract Owner:", owner);
      console.log("✅ All basic functions working correctly!");
      
    } catch (testError) {
      console.log("⚠️  Warning: Could not test contract functionality");
      console.log("Error:", testError.message);
    }

    console.log("\n📋 NEXT STEPS:");
    console.log("1. Save the contract address:", marketplace.address);
    console.log("2. Verify the contract on Core Explorer (if available)");
    console.log("3. Test the contract functions using Hardhat console or frontend");
    console.log("4. Consider setting up a frontend interface");
    
    console.log("\n🔗 Useful Links:");
    console.log("Core Testnet 2 Explorer: https://scan.test2.btcs.network");
    console.log("Contract Address: https://scan.test2.btcs.network/address/" + marketplace.address);

  } catch (error) {
    console.error("\n❌ DEPLOYMENT FAILED");
    console.error("Error:", error.message);
    
    if (error.code === 'INSUFFICIENT_FUNDS') {
      console.error("\n💡 Solution: Add more CORE tokens to your account");
      console.error("Get testnet tokens from Core Testnet 2 faucet");
    } else if (error.code === 'NETWORK_ERROR') {
      console.error("\n💡 Solution: Check your internet connection and RPC URL");
    } else if (error.message.includes('nonce')) {
      console.error("\n💡 Solution: Reset your MetaMask account or wait a few minutes");
    }
    
    console.error("\nDeployment failed with error code:", error.code);
    process.exit(1);
  }
}

// Execute deployment
main()
  .then(() => {
    console.log("\n🎉 Deployment process completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n💥 Critical deployment error:", error);
    process.exit(1);
  });
