const fs = require("fs");
const path = require("path");

// accept command line arguments
const args = process.argv.slice(2);

console.log("args: ", args);

async function main(contractNames) {
  let abiJsonObject = {};

  // read the addresses from the file
  const addresses = JSON.parse(fs.readFileSync("./scripts/addresses.json"));

  // iterate over the contract names, find their ABI, and write them to a file
  for (let i = 0; i < contractNames.length; i++) {
    let contractName = contractNames[i];

    // get the ABI
    const abiJsonValue = fs.readFileSync(
      path.join(
        "./artifacts/contracts",
        contractName + ".sol",
        contractName + ".json"
      )
    );

    const abiJson = JSON.parse(abiJsonValue);

    abiJsonObject[contractName] = {};
    abiJsonObject[contractName].address = addresses[contractName];
    abiJsonObject[contractName].abi = abiJson.abi;
  }

  // write the ABI to a file
  fs.writeFileSync("./contractAbis.json", JSON.stringify(abiJsonObject));
}

main(args).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
