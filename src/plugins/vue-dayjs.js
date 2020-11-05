import dayjs from 'dayjs'

const plugin = {
  install (Vue) {
    Vue.prototype.$dayjs = dayjs
  }
}

export default plugin
