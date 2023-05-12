const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const LiteRideToken = await hre.ethers.getContractFactory("LiteRideToken");

  const liteRideToken = await LiteRideToken.deploy();
  await liteRideToken.deployed();

  console.log("LiteRideToken deployed to:", liteRideToken.address);

  // write the deployed addresses to a file
  const addresses = {
    liteRideToken: liteRideToken.address,
  };

  fs.writeFileSync(
    "./scripts/addresses.json",
    JSON.stringify(addresses, undefined, 2)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
