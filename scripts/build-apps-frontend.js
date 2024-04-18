const fs = require('fs')
const path = require('path')
const chalk = require('chalk')
const { hash: namehash } = require('eth-ens-namehash')
const buidlerTaskNames = require('@nomiclabs/buidler/builtin-tasks/task-names')
const hardhatTaskNames = require('hardhat/builtin-tasks/task-names')


const runOrWrapScript = require('./helpers/run-or-wrap-script')
const { log, logSplitter, logWideSplitter, logHeader, logTx } = require('./helpers/log')
const { exec, execLive } = require('./helpers/exec')
const { readJSON } = require('./helpers/fs')

require('../buidler-ainomo/dist/bootstrap-paths')

const { generateArtifacts } = require('../buidler-ainomo/dist/src/utils/artifact/generateArtifacts')

const { APP_NAMES } = require('./multisig/constants')
const VALID_APP_NAMES = Object.entries(APP_NAMES).map((e) => e[1])


const APPS = process.env.APPS || '*'
const APPS_DIR_PATH = process.env.APPS_DIR_PATH || path.resolve(__dirname, '..', 'apps')
const AINOMO_APM_ENS_NAME = 'ainomopm.eth'

async function publishAppFrontends({
  web3,
  appsDirPath = APPS_DIR_PATH,
  appDirs = APPS
}) {
  const netId = await web3.eth.net.getId()

  logWideSplitter()
  log(`Network ID: ${chalk.yellow(netId)}`)

  appsDirPath = path.resolve(appsDirPath)

  if (appDirs && appDirs !== '*') {
    appDirs = appDirs.split(',')
  } else {
    appDirs = fs.readdirSync(appsDirPath)
  }

  const cwd = process.cwd()

  for (const appDir of appDirs) {
    let app
    try {
      app = await publishAppFrotnend(appDir, appsDirPath, AINOMO_APM_ENS_NAME)
    } finally {
      process.chdir(cwd)
    }
  }
}

async function publishAppFrotnend(appDir, appsDirPath, ainomoApmEnsName) {
  logHeader(`Publishing frontend of the app '${appDir}'`)

  const appRootPath = path.resolve(appsDirPath, appDir)
  const { appFullName, contractPath } = await readArappJSON(appRootPath, network.name)

  log(`App full name: ${chalk.yellow(appFullName)}`)

  if (!appFullName.endsWith('.' + ainomoApmEnsName)) {
    throw new Error(`app full name is not a subdomain of the Ainomo APM ENS domain ${ainomoApmEnsName}`)
  }

  const appName = appFullName.substring(0, appFullName.indexOf('.'))
  log(`App name: ${chalk.yellow(appName)}`)

  if (VALID_APP_NAMES.indexOf(appName) === -1) {
    throw new Error(`app name is not recognized; valid app names are: ${VALID_APP_NAMES.join(', ')}`)
  }

  const appId = namehash(appFullName)
  log(`App ID: ${chalk.yellow(appId)}`)

  logSplitter()

  log('Removing output directory...')
  const distPath = path.join(appRootPath, 'dist')
  await exec(`rm -rf ${distPath}`)

  await execLive('yarn', {
    args: ['build'],
    cwd: path.join(appRootPath, 'app')
  })

  logSplitter()
  log('Generating artifacts...')

  process.chdir(appRootPath)

  const wrappedRun = async (taskName, ...args) => {
    if (taskName !== buidlerTaskNames.TASK_FLATTEN_GET_FLATTENED_SOURCE) {
      return await run(taskName)
    }
    return await run(hardhatTaskNames.TASK_FLATTEN_GET_FLATTENED_SOURCE, {
      files: [contractPath]
    })
  }

  const bre = { artifacts, network, run: wrappedRun }
  await generateArtifacts(distPath, bre)

  logSplitter()
  
  log(`App dist: ${chalk.yellow(distPath)}`)

}

async function readArappJSON(appRoot, netName) {
  const arappJSON = await readJSON(path.join(appRoot, 'arapp.json'))
  const appFullName = getAppName(arappJSON, netName)
  const contractPath = path.resolve(appRoot, arappJSON.path)
  return { appFullName, contractPath }
}

function getAppName(arappJSON, netName) {
  const { environments } = arappJSON
  if (!environments) {
    return null
  }
  if (environments[netName]) {
    return environments[netName].appName
  }
  return (environments.default || {}).appName || null
}

module.exports = runOrWrapScript(publishAppFrontends, module)
