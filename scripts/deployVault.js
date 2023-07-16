const { deployContract, verifyContract } = require("../shared/helpers");
const { getDeployFilteredInfo, getNetwork } = require("../shared/syncParams");
const depositFee = 30;
async function deployVault() {
    const {imple: PriceConsumerV3} = getDeployFilteredInfo("PriceConsumerV3")
    const {imple: LpToken} = getDeployFilteredInfo("LpToken")
    await deployContract("Vault", [LpToken, PriceConsumerV3])
    
    // await verifyContract("Vault", getDeployFilteredInfo("PriceConsumerV3").imple, "contracts/PriceConsumerV3.sol:PriceConsumerV3", [LpToken, PriceConsumerV3])
}
module.exports = deployVault