const { deployContract, verifyContract } = require("../shared/helpers");

const { getDeployFilteredInfo, getNetwork } = require("../shared/syncParams");
const depositFee = 30;

async function deployUSDC() {
    await deployContract("USDC", [])
    
    // await verifyContract("PriceConsumerV3", getDeployFilteredInfo("PriceConsumerV3").imple, "contracts/PriceConsumerV3.sol:PriceConsumerV3", [])
}

module.exports = deployUSDC