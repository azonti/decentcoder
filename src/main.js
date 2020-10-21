import Vue from 'vue'
import App from './App.vue'
import VueWeb3 from './plugins/vue-web3'
import VueTruffleContract from './plugins/vue-truffle-contract'
import VueMaterial from 'vue-material'
import 'vue-material/dist/vue-material.min.css'
import 'vue-material/dist/theme/default.css'
import './registerServiceWorker'
import router from './router'

Vue.use(VueWeb3)
Vue.use(VueTruffleContract)
Vue.use(VueMaterial)

Vue.config.productionTip = false

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')
