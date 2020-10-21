import Vue from 'vue'
import App from './App.vue'
import VueWeb3 from './plugins/vue-web3'
import VueTruffleContract from './plugins/vue-truffle-contract'
import './registerServiceWorker'
import router from './router'

Vue.use(VueWeb3)
Vue.use(VueTruffleContract)

Vue.config.productionTip = false

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')
