import Vue from 'vue'
import App from './App.vue'
import VueDayJS from './plugins/vue-dayjs'
import VueCryptoJS from './plugins/vue-cryptojs'
import VueWeb3 from './plugins/vue-web3'
import VueTruffleContract from './plugins/vue-truffle-contract'
import VueEthereumJS from './plugins/vue-ethereumjs'
import VueIPFS from './plugins/vue-ipfs'
import VueMaterial from 'vue-material'
import 'vue-material/dist/vue-material.min.css'
import 'vue-material/dist/theme/default.css'
import './registerServiceWorker'
import router from './router'

Vue.use(VueDayJS)
Vue.use(VueCryptoJS)
Vue.use(VueWeb3)
Vue.use(VueTruffleContract)
Vue.use(VueEthereumJS)
Vue.use(VueIPFS)
Vue.use(VueMaterial)

Vue.config.productionTip = false

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')
