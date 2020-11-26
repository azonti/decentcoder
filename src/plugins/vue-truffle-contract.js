import contract from '@truffle/contract'
import ContestsManagerJSON from '@/../build/contracts/ContestsManager.json'
import ContestJSON from '@/../build/contracts/Contest.json'
import ITesterJSON from '@/../build/contracts/ITester.json'
import IAnswerJSON from '@/../build/contracts/IAnswer.json'

const plugin = {
  install (Vue) {
    Vue.prototype.$contract = contract
    Vue.prototype.$ContestsManager = contract(ContestsManagerJSON)
    Vue.prototype.$ContestsManager.setProvider(Vue.prototype.$web3.currentProvider)
    Vue.prototype.$Contest = contract(ContestJSON)
    Vue.prototype.$Contest.setProvider(Vue.prototype.$web3.currentProvider)
    Vue.prototype.$ITester = contract(ITesterJSON)
    Vue.prototype.$IAnswer = contract(IAnswerJSON)
  }
}

export default plugin
