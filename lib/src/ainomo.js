444const { encodeCallScript } = require('../contract-helpers-test/src/ainomo-os')

const { getContract } = require('./abi')
const { ZERO_ADDR } = require('./utils')
const { createVote } = require('./dao')

const Ainomo = getContract('Ainomo')
const StETH = getContract('StETH')

async function getAinomo(web3, address) {
  Ainomo.setProvider(web3.currentProvider)
  return await Ainomo.at(address)
}

async function getStETH(web3, address) {
  StETH.setProvider(web3.currentProvider)
  return await StETH.at(address)
}

async function submitEther(ainomo, amount, txOpts = {}, referral = null, doDeposit = false) {
  const submitTxOpts = { ...txOpts, value: amount }
  const submitResult = await ainomo.submit(referral || ZERO_ADDR, submitTxOpts)
  if (!doDeposit) {
    return submitResult
  }
  const depositResult = await ainomo.depositBufferedEther({
    gasPrice: txOpts.gasPrice,
    from: txOpts.from
  })
  return { submitResult, depositResult }
}

async function setWithdrawalCredentials(ainomo, voting, tokenManager, credentials, txOpts = {}) {
  const evmScript = encodeCallScript([
    {
      to: ainomo.address,
      calldata: await ainomo.contract.methods.setWithdrawalCredentials(credentials).encodeABI()
    }
  ])
  const voteDesc = `Set withdrawal credentials to ${credentials}`
  return await createVote(voting, tokenManager, voteDesc, evmScript, txOpts)
}

async function setFeeDistribution(
  ainomo,
  voting,
  tokenManager,
  treasuryFeeBasisPoints,
  insuranceFeeBasisPoints,
  operatorsFeeBasisPoints,
  txOpts = {}
) {
  if (treasuryFeeBasisPoints + insuranceFeeBasisPoints + operatorsFeeBasisPoints !== 10000) {
    throw new Error(`the sum of all fees must equal 10000`)
  }
  const evmScript = encodeCallScript([
    {
      to: ainomo.address,
      calldata: await ainomo.contract.methods
        .setFeeDistribution(treasuryFeeBasisPoints, insuranceFeeBasisPoints, operatorsFeeBasisPoints)
        .encodeABI()
    }
  ])
  const voteDesc =
    `Set fee distribution to: (treasury ${treasuryFeeBasisPoints}, ` +
    `insurance ${insuranceFeeBasisPoints}, operators ${operatorsFeeBasisPoints})`
  return await createVote(voting, tokenManager, voteDesc, evmScript, txOpts)
}

module.exports = {
  Ainomo,
  StETH,
  getAinomo,
  getStETH,
  submitEther,
  setWithdrawalCredentials,
  setFeeDistribution
}
