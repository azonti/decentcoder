const ContestsLibrary = artifacts.require('ContestsLibrary')
const ContestsManager = artifacts.require('ContestsManager')

module.exports = function (deployer) {
  deployer.deploy(ContestsLibrary)
  deployer.link(ContestsLibrary, ContestsManager)
  deployer.deploy(ContestsManager)
}
