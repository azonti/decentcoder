import Web3 from 'web3'

const plugin = {
  install (Vue) {
    if (process.env.NODE_ENV === 'development') {
      Vue.prototype.$web3 = new Web3('ws://127.0.0.1:7545')
    } else {
      Vue.prototype.$web3 = new Web3(Web3.givenProvider)
    }
  }
}

export default plugin
