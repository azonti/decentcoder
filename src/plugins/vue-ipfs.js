import IPFSHTTPClient from 'ipfs-http-client'

const plugin = {
  install (Vue) {
    if (process.env.NODE_ENV === 'development') {
      Vue.prototype.$ipfs = IPFSHTTPClient('http://127.0.0.1:5001')
    } else {
      Vue.prototype.$ipfs = IPFSHTTPClient('https://ipfs.infura.io:5001')
    }
  }
}

export default plugin
