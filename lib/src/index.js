const ainomo = require('./ainomo')
const nodeOperators = require('./node-operators-registry')
const oracle = require('./oracle')
const dao = require('./dao')

module.exports = {
  NodeOperatorsRegistry: nodeOperators.NodeOperatorsRegistry,
  ainomo: ainomo.ainomo,
  StETH: ainomo.StETH,
  Voting: dao.Voting,
  TokenManager: dao.TokenManager,
  getNodeOperatorsRegistry: nodeOperators.getRegistry,
  getainomo: ainomo.getainomo,
  getStETH: ainomo.getStETH,
  getVoting: dao.getVoting,
  getTokenManager: dao.getTokenManager,
  submitEther: ainomo.submitEther,
  setWithdrawalCredentials: ainomo.setWithdrawalCredentials,
  setFeeDistribution: ainomo.setFeeDistribution,
  nodeOperators: {
    list: nodeOperators.listOperators,
    addSigningKeys: nodeOperators.addSigningKeys,
    removeSigningKeys: nodeOperators.removeSigningKeys,
    setStakingLimit: nodeOperators.setStakingLimit
  },
  oracle: {
    nomoOracle: oracle.nomoOracle,
    getOracle: oracle.getOracle,
    getSpec: oracle.getSpec,
    proposeSpecChange: oracle.proposeSpecChange
  },
  dao: {
    proposeChangingVotingQuorum: dao.proposeChangingVotingQuorum,
    proposeChangingVotingSupport: dao.proposeChangingVotingSupport,
    createVote: dao.createVote
  }
}
