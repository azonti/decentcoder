const ContestsManager = artifacts.require('ContestsManager')

module.exports = function (deployer) {
  deployer.deploy(ContestsManager)
}
