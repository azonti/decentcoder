import VM from '@ethereumjs/vm'
import { Transaction } from '@ethereumjs/tx'
import { Account, Address } from 'ethereumjs-util'

const plugin = {
  install (Vue) {
    Vue.prototype.$EthereumJS = { VM, Transaction, Account, Address }
  }
}

export default plugin
