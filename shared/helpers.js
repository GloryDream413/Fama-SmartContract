const fs = require("fs");
const path = require("path");
const parse = require("csv-parse");
const { run } = require('hardhat')

const { CORE_URL, CORE_DEPLOY_KEY } = require("../env.json");
const { syncDeployInfo, addGasUsed } = require("./syncParams");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getFrameSigner() {
  try {
    const accounts = await ethers.getSigners();
    const signer = accounts[0]
    return signer;
  } catch (e) {
    throw new Error(`getFrameSigner error: ${e.toString()}`);
  }
}

async function sendTxn(txnPromise, label) {
  const txn = await txnPromise;
  console.info(`Sending ${label}...`);
  const ret = await txn.wait();
  addGasUsed(ret.cumulativeGasUsed.toString())
  console.info(`... Sent! ${txn.hash}`);
  await sleep(2000);
  return txn;
}

async function callWithRetries(func, args, retriesCount = 3) {
  let i = 0;
  while (true) {
    i++;
    try {
      return await func(...args);
    } catch (ex) {
      if (i === retriesCount) {
        console.error("call failed %s times. throwing error", retriesCount);
        throw ex;
      }
      console.error("call i=%s failed. retrying....", i);
      console.error(ex.message);
    }
  }
}

async function deployContract(name, args, label, options, registerName) {
  if (!options && typeof label === "object") {
    label = null;
    options = label;
  }

  let info = name;
  if (label) {
    info = name + ":" + label;
  }
  const contractFactory = await ethers.getContractFactory(name, options);
  let contract;
  contract = await contractFactory.deploy(...args);

  const argStr = args.map((i) => `"${i}"`).join(" ");
  console.info(`Deploying ${info} ${contract.address} ${argStr}`);
  const ret = await contract.deployTransaction.wait();

  console.info("... Completed!");

  addGasUsed(ret.cumulativeGasUsed.toString())

  syncDeployInfo(registerName ?? name, {
    name: registerName ?? name,
    imple: contract.address,
  });

  return contract;
}

const verifyContract = async (name, address, contractPath, args) => {
  console.info(`Verifying ${name} ...`)
  await run('verify:verify', {
    contract: contractPath,
    address: address,
    constructorArguments: args ? [...args] : []
  })
}

async function contractAt(name, address, provider, options) {
  let contractFactory = await ethers.getContractFactory(name, options);
  if (provider) {
    contractFactory = contractFactory.connect(provider);
  }
  return await contractFactory.attach(address);
}

// batchLists is an array of lists
async function processBatch(batchLists, batchSize, handler) {
  let currentBatch = [];
  const referenceList = batchLists[0];

  for (let i = 0; i < referenceList.length; i++) {
    const item = [];

    for (let j = 0; j < batchLists.length; j++) {
      const list = batchLists[j];
      item.push(list[i]);
    }

    currentBatch.push(item);

    if (currentBatch.length === batchSize) {
      console.log(
        "handling currentBatch",
        i,
        currentBatch.length,
        referenceList.length
      );
      await handler(currentBatch);
      currentBatch = [];
    }
  }

  if (currentBatch.length > 0) {
    console.log(
      "handling final batch",
      currentBatch.length,
      referenceList.length
    );
    await handler(currentBatch);
  }
}

async function updateTokensPerInterval(distributor, tokensPerInterval, label) {
  const prevTokensPerInterval = await distributor.tokensPerInterval();
  if (prevTokensPerInterval.eq(0)) {
    // if the tokens per interval was zero, the distributor.lastDistributionTime may not have been updated for a while
    // so the lastDistributionTime should be manually updated here
    await sendTxn(
      distributor.updateLastDistributionTime({ gasLimit: 1000000 }),
      `${label}.updateLastDistributionTime`
    );
  }
  await sendTxn(
    distributor.setTokensPerInterval(tokensPerInterval, { gasLimit: 1000000 }),
    `${label}.setTokensPerInterval`
  );
}

module.exports = {
  getFrameSigner,
  sendTxn,
  deployContract,
  verifyContract,
  contractAt,
  callWithRetries,
  processBatch,
  updateTokensPerInterval,
  sleep,
};
