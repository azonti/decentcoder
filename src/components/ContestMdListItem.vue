<template>
  <md-list-item :to="'/contests/' + address">
      <md-icon>cake</md-icon>
      <div class="md-list-item-text">
        <span>{{ name }}</span>
        <span>by {{ organizer }}</span>
      </div>
  </md-list-item>
</template>

<script>
import IPFSCat from '@/mixins/ipfs-cat.js'

export default {
  name: 'ContestMdListItem',
  props: {
    address: String
  },
  mixins: [
    IPFSCat
  ],
  data () {
    return {
      contest: null,
      createdBlockNumber: 0,
      organizer: '',
      name: ''
    }
  },
  async mounted () {
    this.contest = await this.$Contest.at(this.address)

    await this.setCreatedBlockNumber()

    await Promise.all([
      this.setOrganizer(),
      this.setName()
    ])
  },
  methods: {
    async setCreatedBlockNumber () {
      this.createdBlockNumber = await this.contest.createdBlockNumber()
    },
    async setOrganizer () {
      this.organizer = await this.contest.organizer()
    },
    async setName () {
      const events = await this.contest.getPastEvents('PhaseChanged', { fromBlock: this.createdBlockNumber })
      const transaction = await this.$web3.eth.getTransaction(events.filter(event => event.returnValues.phase === '0')[0].transactionHash)
      const cid = this.$web3.eth.abi.decodeParameters(this.$ContestsManager.abi[2].inputs, transaction.input.substring(10)).cid
      this.name = await this.ipfsCat(cid + '/name')
    }
  }
}
</script>
