const fs = require('fs');

const networkInfo = {
    network: 'core',
    gasUsed: 0,
}

const setNetwork = (_network) => {
    networkInfo.network = _network
    networkInfo.gasUsed = 0
}

const addGasUsed = (gas) => {
    networkInfo.gasUsed += parseInt(gas)
}

const getGasUsed = () => {
    return networkInfo.gasUsed
}

const getNetwork = () => {
    return networkInfo.network
}

const getDeployInfo = () => {
    try {
    return JSON.parse(fs.readFileSync(`scripts/deploy-${networkInfo.network}.json`));
    } catch (err) {
        // console.log(err)
        return []
    }
}

const getDeployFilteredInfo = (name) => {
    try {
    const tr = JSON.parse(fs.readFileSync(`scripts/deploy-${networkInfo.network}.json`));
    return tr.find(t => t.name === name)
    } catch (err) {
        // console.log(err)
        return []
    }
}

const syncDeployInfo = (_name, _info) => {
    let _total = getDeployInfo()

    _total = [..._total.filter(t => t.name !== _name), _info];
    fs.writeFileSync(`scripts/deploy-${networkInfo.network}.json`, JSON.stringify(_total));
    return _total;
}

module.exports = { getNetwork, setNetwork, getDeployFilteredInfo, syncDeployInfo, addGasUsed, getGasUsed }
