const hre = require("hardhat");
const fs = require("fs");
const { ethers } = require("ethers");
const { ZERO_ADDRESS } = require("@ethereum-attestation-service/eas-sdk");

async function main() {
  // Read the addresses from the file
  const addresses = JSON.parse(fs.readFileSync("./scripts/addresses.json"));

  console.log("EAS Schema Registry address: ", addresses.easSchemaRegistry);
  console.log("EAS address: ", addresses.eas);

  const eas = await hre.ethers.getContractAt("EAS", addresses.eas);
  const easSchemaRegistry = await hre.ethers.getContractAt(
    "SchemaRegistry",
    addresses.easSchemaRegistry
  );

  const userSchema = "string name, string email, string phone";

  // register the schema
  const tx = await easSchemaRegistry.register(userSchema, ZERO_ADDRESS, false);
  await tx.wait();

  // get the schema id in the event
  const receipt = await hre.ethers.provider.getTransactionReceipt(tx.hash);
  console.log("receipt: ", receipt);
  const event = receipt.logs[0];
  console.log("event: ", event);
  const eventFragment = easSchemaRegistry.interface.parseLog(event);
  const eventArgs = eventFragment.args;
  const uid = eventArgs.uid;
  console.log("uid: ", uid);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
