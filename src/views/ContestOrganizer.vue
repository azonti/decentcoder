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
      period: null,
      announcementPeriodFinish: null,
      submissionPeriodFinish: null,
      claimPeriodFinish: null,
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
        !this.announcementPeriodFinish ||
        !this.submissionPeriodFinish ||
        !this.claimPeriodFinish ||
        !this.timedrift
      ) return ''

      if (this.period.eq(this.$web3.utils.toBN(0))) {
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.announcementPeriodFinish)) return 'announcement'
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.announcementPeriodFinish.add(this.timedrift))) return 'betweenAnnouncementAndSubmission'
        return 'abnormalTermination'
      }
      if (this.period.eq(this.$web3.utils.toBN(1))) {
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.submissionPeriodFinish)) return 'submission'
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.submissionPeriodFinish.add(this.timedrift))) return 'betweenSubmissionAndClaim'
        return 'abnormalTermination'
      }
      if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.claimPeriodFinish)) return 'claim'
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

      this.$web3.eth.subscribe('newBlockHeaders').on('data', this.setBlockTimestamp)
      this.contest.PeriodChanged().on('data', r => this.setPeriod(r.returnValues.period))

      await Promise.all([
        this.contest.name().then(this.setPageName),
        this.$web3.eth.getBlock('latest').then(this.setBlockTimestamp),
        this.contest.period().then(this.setPeriod),
        this.contest.announcementPeriodFinish().then(this.setAnnouncementPeriodFinish),
        this.contest.submissionPeriodFinish().then(this.setSubmissionPeriodFinish),
        this.contest.claimPeriodFinish().then(this.setClaimPeriodFinish),
        this.contest.timedrift().then(this.setTimedrift)
      ])
    },
    setPageName (pageName) {
      this.$emit('set-page-name', pageName + ' Organizer')
    },
    setBlockTimestamp (blockHeader) {
      this.blockTimestamp = blockHeader.timestamp
    },
    async setPeriod (period) {
      if (this.$web3.utils.isBN(period)) {
        this.period = period
      } else {
        this.period = this.$web3.utils.toBN(period)
      }
    },
    setAnnouncementPeriodFinish (announcementPeriodFinish) {
      this.announcementPeriodFinish = announcementPeriodFinish
    },
    setSubmissionPeriodFinish (submissionPeriodFinish) {
      this.submissionPeriodFinish = submissionPeriodFinish
    },
    setClaimPeriodFinish (claimPeriodFinish) {
      this.claimPeriodFinish = claimPeriodFinish
    },
    setTimedrift (timedrift) {
      this.timedrift = timedrift
    },
    async startSubmissionPeriod () {
      this.startingSubmissionPeriod = true

      const accounts = await this.$web3.eth.getAccounts()
      await this.contest.startSubmissionPeriod(this.passphrase, { from: accounts[0] })

      this.startingSubmissionPeriod = false
    },
    async startClaimPeriod () {
      this.startingClaimPeriod = true

      const submissionJSON = await document.getElementById('postclaimTesterJSON').files[0].text()
      const submissionCC = JSON.parse(submissionJSON).bytecode

      const accounts = await this.$web3.eth.getAccounts()
      await this.contest.startClaimPeriod(submissionCC, { from: accounts[0] })

      this.startingClaimPeriod = false
    }
  }
}
</script>
