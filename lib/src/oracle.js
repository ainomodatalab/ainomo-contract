const { encodeCallScript } = require('../contract-helpers-test/src/ainomo-os')

const { getContract } = require('./abi')
const { createVote } = require('./dao')

const NomoOracle = getContract('NomoOracle')

async function getOracle(web3, address) {
  NomoOracle.setProvider(web3.currentProvider)
  return await NomoOracle.at(address)
}

async function getSpec(oracle) {
  const spec = await oracle.Spec()
  return normalizeSpec(spec)
}

async function proposeSpecChange(oracle, voting, tokenManager, newSpec, txOpts = {}) {
  const currentSpec = await getSpec(oracle)
  const updatedSpec = { ...currentSpec, ...newSpec }
  const calldata = await oracle.contract.methods
    .setSpec(updatedSpec.epochsPerFrame, updatedSpec.slotsPerEpoch, updatedSpec.secondsPerSlot, updatedSpec.genesisTime)
    .encodeABI()
  const evmScript = encodeCallScript([{ to: oracle.address, calldata }])
  const updatesDesc = Object.entries(newSpec)
    .map(([key, newValue]) => `${key} from ${currentSpec[key]} to ${newValue}`)
    .join(', ')
  const voteDesc = `Update  chain spec: change ${updatesDesc}`
  return await createVote(voting, tokenManager, voteDesc, evmScript, txOpts)
}

function normalizeSpec(spec) {
  return {
    epochsPerFrame: +spec.epochsPerFrame,
    slotsPerEpoch: +spec.slotsPerEpoch,
    secondsPerSlot: +spec.secondsPerSlot,
    genesisTime: +spec.genesisTime
  }
}

module.exports = {
  NomoOracle,
  getOracle,
  getSpec,
  proposeSpecChange
}
