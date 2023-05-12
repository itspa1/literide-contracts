const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const accounts = await hre.ethers.getSigners();

  // Read the addresses from the file
  const addresses = JSON.parse(fs.readFileSync("./scripts/addresses.json"));
  console.log("LiteRideToken address: ", addresses.LiteRideToken);

  const liteRideToken = await hre.ethers.getContractAt(
    "LiteRideToken",
    addresses.LiteRideToken
  );

  const liteRideVoteToken = await hre.ethers.getContractAt(
    "LiteRideVoteToken",
    addresses.LiteRideVoteToken
  );

  const liteRideTimelock = await hre.ethers.getContractAt(
    "LiteRideTimelock",
    addresses.LiteRideTimelock
  );

  const liteRideGovernor = await hre.ethers.getContractAt(
    "LiteRideGovernor",
    addresses.LiteRideGovernor
  );

  const riderAccount = accounts[accounts.length - 1];
  const driverAccount = accounts[accounts.length - 2];

  const liteRideTokenBalance = await liteRideToken.balanceOf(
    riderAccount.address
  );

  console.log(
    "LiteRideToken balance in ether: ",
    hre.ethers.utils.formatEther(liteRideTokenBalance)
  );

  const liteRideTokenBalanceForDriver = await liteRideToken.balanceOf(
    driverAccount.address
  );

  console.log(
    "LiteRideToken balance in ether for driver: ",
    hre.ethers.utils.formatEther(liteRideTokenBalanceForDriver)
  );

  const liteRideVoteTokenBalance = await liteRideVoteToken.balanceOf(
    riderAccount.address
  );

  console.log(
    "LiteRideVoteToken balance in ether:",
    hre.ethers.utils.formatEther(liteRideVoteTokenBalance)
  );

  const liteRideVoteTokenBalanceForDriver = await liteRideVoteToken.balanceOf(
    driverAccount.address
  );

  console.log(
    "LiteRideVoteToken balance in ether for driver: ",
    hre.ethers.utils.formatEther(liteRideVoteTokenBalanceForDriver)
  );

  const liteRideTokenBalanceForLiteRideContract = await liteRideToken.balanceOf(
    addresses.LiteRide
  );

  console.log(
    "LiteRideToken balance in ether for LiteRide contract: ",
    hre.ethers.utils.formatEther(liteRideTokenBalanceForLiteRideContract)
  );

  const liteRideTokenBalanceForLiteRideTimelock = await liteRideToken.balanceOf(
    addresses.LiteRideTimelock
  );

  console.log(
    "LiteRideToken balance in ether for LiteRideTimelock contract: ",
    hre.ethers.utils.formatEther(liteRideTokenBalanceForLiteRideTimelock)
  );

  // list all the functions that we can call on the contract
  const liteRideGovernorFunctions = liteRideGovernor.interface.fragments.map(
    (f) => f.name
  );

  console.log("LiteRideGovernor functions: ", liteRideGovernorFunctions);

  const liteRideTimelockFunctions = liteRideTimelock.interface.fragments.map(
    (f) => f.name
  );

  console.log("LiteRideTimelock functions: ", liteRideTimelockFunctions);

  const proposal = [
    ["0x9d4454B023096f34B160D6B654540c56A1F81688"],
    [0],
    [
      "0x60e4b2260000000000000000000000000000000000000000000000000000000000000002",
    ],
    "0xdcbdb40cad2629715db424394e3685f2893f5f52a5ceb7c6a6a30ed22c19b853",
  ];

  const queueProposal = await liteRideGovernor.queue(...proposal);

  const response = await queueProposal.wait();

  console.log("response: ", response);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
