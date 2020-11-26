const mixin = {
  methods: {
    async ipfsCat (cidPath) {
      let data = new Uint8Array()
      for await (const chunk of this.$ipfs.cat('/ipfs/' + cidPath)) {
        const newData = new Uint8Array(data.length + chunk.length)
        newData.set(data)
        newData.set(chunk, data.length)
        data = newData
      }
      return (new TextDecoder()).decode(data)
    }
  }
}

export default mixin
