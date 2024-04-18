require('../buidler-ainomo')

const baseConfig = require('./hardhat.config.js')
const ainomoConfig = {}

if (process.env.APP_FRONTEND_PATH) {
  ainomoConfig.appSrcPath = process.env.APP_FRONTEND_PATH
  ainomoConfig.appBuildOutputPath = process.env.APP_FRONTEND_DIST_PATH
}

module.exports = {
  ...baseConfig,
  ainomo: {
    ...baseConfig.ainomo,
    ...ainomoConfig
  }
}
