import CryptoJS from 'crypto-js'

const plugin = {
  install (Vue) {
    Vue.prototype.$CryptoJS = CryptoJS
  }
}

export default plugin
