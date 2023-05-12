const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const proposalId =
    "0x097204ac559c544f3d396b399e81777cd0a9ecc5a6fcc832f97e354a135fcd52";
  const accounts = await hre.ethers.getSigners();

  // Read the addresses from the file
  const addresses = JSON.parse(fs.readFileSync("./scripts/addresses.json"));

  const riderAccount = accounts[accounts.length - 1];
  const driverAccount = accounts[accounts.length - 2];
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
