// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const fs = require("fs");

const MIN_DELAY = 1; // 1 second
const PROPOSAL_THRESHOLD = 0;
const VOTING_DELAY = 1; // 1 Block delay
const VOTING_PERIOD = 20; // 20 blocks

async function main() {
  // initially we need to deploy the EAS SchemaRegistry contract
  // we use the deployed address in the EAS contract
  // then we can use the schema registry to register schemas

  const wallets = await hre.ethers.getSigners();

  // We get the contract to deploy
  const LiteRideVoteToken = await hre.ethers.getContractFactory(
    "LiteRideVoteToken"
  );
  const liteRideVoteToken = await LiteRideVoteToken.deploy();
  await liteRideVoteToken.deployed();

  console.log("LiteRideVoteToken deployed to:", liteRideVoteToken.address);

  const LiteRideToken = await hre.ethers.getContractFactory("LiteRideToken");
  const liteRideToken = await LiteRideToken.deploy();
  await liteRideToken.deployed();

  console.log("LiteRideToken deployed to:", liteRideToken.address);

  // For all addresses in wallet, we'll give them 10LTR tokens and 1LTRV (for testing)
  for (let i = 0; i < wallets.length; i++) {
    const liteRideTokenToTransfer = hre.ethers.utils.parseEther("10");
    await liteRideToken.transfer(wallets[i].address, liteRideTokenToTransfer);
    console.log("gave 10 LTR to", wallets[i].address);
    const liteRideVoteTokenToTransfer = hre.ethers.utils.parseEther("1");
    await liteRideVoteToken.transfer(
      wallets[i].address,
      liteRideVoteTokenToTransfer
    );

    // delegate to self
    await liteRideVoteToken.connect(wallets[i]).delegate(wallets[i].address);

    console.log("gave 1 LTRV to", wallets[i].address);
  }

  const LiteRideTimelock = await hre.ethers.getContractFactory(
    "LiteRideTimelock"
  );
  const liteRideTimelock = await LiteRideTimelock.deploy(
    MIN_DELAY,
    [],
    [],
    wallets[0].address
  );

  await liteRideTimelock.deployed();

  console.log("LiteRideTimelock deployed to:", liteRideTimelock.address);

  const LiteRideGovernor = await hre.ethers.getContractFactory(
    "LiteRideGovernor"
  );
  const liteRideGovernor = await LiteRideGovernor.deploy(
    liteRideVoteToken.address,
    liteRideToken.address,
    liteRideTimelock.address
  );

  await liteRideGovernor.deployed();

  console.log("LiteRideGovernor deployed to:", liteRideGovernor.address);

  const LiteRide = await hre.ethers.getContractFactory("LiteRide");
  const liteRide = await LiteRide.deploy(liteRideToken.address);

  await liteRide.deployed();

  console.log("LiteRide deployed to:", liteRide.address);

  // give ownership of the LiteRide contract to the timelock
  await liteRide.transferOwnership(liteRideTimelock.address);

  console.log("LiteRide ownership transferred to:", liteRideTimelock.address);

  // move funds to the timelock
  await liteRideToken.transfer(
    liteRideTimelock.address,
    await liteRideToken.balanceOf(wallets[0].address)
  );

  console.log("moved all LiteRide tokens to timelock");

  await liteRideVoteToken.transfer(
    liteRideTimelock.address,
    await liteRideVoteToken.balanceOf(wallets[0].address)
  );

  console.log("moved all LiteRideVote tokens to timelock");

  const proposerRole = await liteRideTimelock.PROPOSER_ROLE();
  const executorRole = await liteRideTimelock.EXECUTOR_ROLE();
  const timelockAdminRole = await liteRideTimelock.TIMELOCK_ADMIN_ROLE();

  // set proposer role to the governor
  await liteRideTimelock.grantRole(proposerRole, liteRideGovernor.address);

  console.log("LiteRideGovernor granted proposer role");

  // set executor role to everyone (a passed proposal can be executed by anyone)
  await liteRideTimelock.grantRole(
    executorRole,
    hre.ethers.constants.AddressZero
  );

  console.log("Everyone granted executor role");

  // revoke timelock admin role from the deployer
  await liteRideTimelock.revokeRole(timelockAdminRole, wallets[0].address);

  console.log(
    "Deployer revoked timelock admin role! Everything is now done via proposals"
  );

  // NOW everything needs to be done via proposals

  // write the deployed addresses to a file
  const addresses = {
    LiteRideToken: liteRideToken.address,
    LiteRide: liteRide.address,
    LiteRideGovernor: liteRideGovernor.address,
    LiteRideVoteToken: liteRideVoteToken.address,
    LiteRideTimelock: liteRideTimelock.address,
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
