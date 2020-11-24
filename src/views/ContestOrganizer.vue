<template>
  <div>
    <div v-if="realPeriod === 'betweenAnnouncementAndSubmission'">
      <form @submit.prevent="startSubmissionPeriod">
        <md-field>
          <label>Passphrase</label>
          <md-input type="password" required v-model="passphrase"/>
        </md-field>
        <md-button type="submit" :disabled="startingSubmissionPeriod">Start Submission Period</md-button>
      </form>
    </div>
    <div v-else-if="realPeriod === 'betweenSubmissionAndClaim'">
      <form @submit.prevent="startClaimPeriod">
        <md-field>
          <label>PostclaimTester.json</label>
          <md-file id="postclaimTesterJSON" required/>
        </md-field>
        <md-button type="submit" :disabled="startingClaimPeriod">Start Claim Period</md-button>
      </form>
    </div>
    <div v-else>
      {{ realPeriod }}
    </div>
  </div>
</template>

<script>
export default {
  name: 'ContestOrganizer',
  data () {
    return {
      contest: null,
      blockTimestamp: 0,
      createdBlockNumber: 0,
      period: null,
      announcementPeriodFinishedAt: null,
      submissionPeriodFinishedAt: null,
      claimPeriodFinishedAt: null,
      timedrift: null,
      passphrase: '',
      startingSubmissionPeriod: false,
      startingClaimPeriod: false
    }
  },
  computed: {
    realPeriod () {
      if (
        !this.blockTimestamp ||
        !this.period ||
        !this.announcementPeriodFinishedAt ||
        !this.submissionPeriodFinishedAt ||
        !this.claimPeriodFinishedAt ||
        !this.timedrift
      ) return ''

      if (this.period.eq(this.$web3.utils.toBN(0))) {
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.announcementPeriodFinishedAt)) return 'announcement'
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.announcementPeriodFinishedAt.add(this.timedrift))) return 'betweenAnnouncementAndSubmission'
        return 'abnormalTermination'
      }
      if (this.period.eq(this.$web3.utils.toBN(1))) {
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.submissionPeriodFinishedAt)) return 'submission'
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.submissionPeriodFinishedAt.add(this.timedrift))) return 'betweenSubmissionAndClaim'
        return 'abnormalTermination'
      }
      if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.claimPeriodFinishedAt)) return 'claim'
      return 'normalTermination'
    }
  },
  async mounted () {
    await this.initialize()
  },
  watch: {
    async $route (to, from) {
      await this.initialize()
    }
  },
  methods: {
    async initialize () {
      this.contest = await this.$Contest.at(this.$route.params.address)

      await this.setCreatedBlockNumber()

      this.$web3.eth.subscribe('newBlockHeaders').on('data', this.setBlockTimestamp)
      this.contest.PeriodChanged().on('data', event => this.setPeriod(event))

      await Promise.all([
        this.setBlockTimestamp(),
        this.setPeriod(),
        this.setAnnouncementPeriodFinishedAt(),
        this.setSubmissionPeriodFinishedAt(),
        this.setClaimPeriodFinishedAt(),
        this.setTimedrift(),
        this.setPageName()
      ])
    },
    async setBlockTimestamp (blockHeader) {
      if (blockHeader) {
        this.blockTimestamp = blockHeader.timestamp
      } else {
        const block = await this.$web3.eth.getBlock('latest')
        this.blockTimestamp = block.timestamp
      }
    },
    async setCreatedBlockNumber () {
      this.createdBlockNumber = await this.contest.createdBlockNumber()
    },
    async setPeriod (event) {
      if (event) {
        this.period = this.$web3.utils.toBN(event.returnValues.period)
      } else {
        this.period = await this.contest.period()
      }
    },
    async setAnnouncementPeriodFinishedAt () {
      this.announcementPeriodFinishedAt = await this.contest.announcementPeriodFinishedAt()
    },
    async setSubmissionPeriodFinishedAt () {
      this.submissionPeriodFinishedAt = await this.contest.submissionPeriodFinishedAt()
    },
    async setClaimPeriodFinishedAt () {
      this.claimPeriodFinishedAt = await this.contest.claimPeriodFinishedAt()
    },
    async setTimedrift () {
      this.timedrift = await this.contest.timedrift()
    },
    async setPageName () {
      const events = await this.contest.getPastEvents('PeriodChanged', { fromBlock: this.createdBlockNumber })
      const transaction = await this.$web3.eth.getTransaction(events.filter(event => event.returnValues.period === '0')[0].transactionHash)
      const cid = this.$web3.eth.abi.decodeParameters(this.$ContestsManager.abi[2].inputs, transaction.input.substring(10)).cid
      let name = new Uint8Array()
      for await (const chunk of this.$ipfs.cat('/ipfs/' + cid + '/name')) {
        const newName = new Uint8Array(name.length + chunk.length)
        newName.set(name)
        newName.set(chunk, name.length)
        name = newName
      }
      this.$emit('set-page-name', (new TextDecoder()).decode(name) + ' Organizer')
    },
    async startSubmissionPeriod () {
      this.startingSubmissionPeriod = true

      const accounts = await this.$web3.eth.getAccounts()
      await this.contest.startSubmissionPeriod(this.passphrase, { from: accounts[0] })

      this.startingSubmissionPeriod = false
    },
    async startClaimPeriod () {
      this.startingClaimPeriod = true

      const accounts = await this.$web3.eth.getAccounts()

      const postclaimTesterJSON = await document.getElementById('postclaimTesterJSON').files[0].text()
      const PostclaimTester = this.$contract(JSON.parse(postclaimTesterJSON))
      PostclaimTester.setProvider(this.$web3.currentProvider)
      const postclaimTester = await PostclaimTester.new({ from: accounts[0] })

      await this.contest.startClaimPeriod(postclaimTester.address, { from: accounts[0] })

      this.startingClaimPeriod = false
    }
  }
}
</script>
