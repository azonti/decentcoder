<template>
  <div>
    <md-list class="md-double-line">
      <ContestMdListItem v-for="address in addresses" :address="address" :key="address"/>
    </md-list>
    <md-button class="md-fab md-fab-bottom-right md-primary" to="/newContest" exact>
      <md-icon>add</md-icon>
    </md-button>
  </div>
</template>

<script>
import ContestMdListItem from '@/components/ContestMdListItem'

export default {
  name: 'Contests',
  components: {
    ContestMdListItem
  },
  data () {
    return {
      contestsManager: null,
      addresses: []
    }
  },
  async mounted () {
    this.contestsManager = await this.$ContestsManager.deployed()

    this.contestsManager.ContestsChanged().on('data', this.setAddresses)

    await this.setAddresses()
  },
  methods: {
    async setAddresses (event) {
      if (event) {
        if (this.addresses.includes(event.returnValues.contest)) {
          this.addresses = this.addresses.filter(address => address !== event.returnValues.contest)
        } else {
          this.addresses.push(event.returnValues.contest)
        }
      } else {
        this.addresses = await this.contestsManager.contests()
      }
    }
  }
}
</script>
