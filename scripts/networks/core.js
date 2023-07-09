const deployLpToken = require("../deployLpToken.js");
const deployOracle = require("../deployOracle.js");
const deployVault = require("../deployVault.js");
const deployUSDC = require("../deployUSDC.js");
const deploy_core = async () => {
    await deployLpToken()
    await deployOracle()
    await deployVault()
    // await deployUSDC()
}

module.exports = { deploy_core };