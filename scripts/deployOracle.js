const { deployContract, verifyContract } = require("../shared/helpers");

const { getDeployFilteredInfo, getNetwork } = require("../shared/syncParams");
const depositFee = 30;

async function deployOracle() {
    await deployContract("PriceConsumerV3", [])
    
    // await verifyContract("PriceConsumerV3", getDeployFilteredInfo("PriceConsumerV3").imple, "contracts/PriceConsumerV3.sol:PriceConsumerV3", [])
}

module.exports = deployOracle