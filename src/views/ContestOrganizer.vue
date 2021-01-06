<template>
  <div>
    <div v-if="realPhase === 'betweenAnnouncementAndSubmission'">
      <form @submit.prevent="startSubmissionPhase">
        <md-field>
          <label>Passphrase</label>
          <md-input type="password" required v-model="passphrase"/>
        </md-field>
        <md-button type="submit" :disabled="startingSubmissionPhase">Start Submission Phase</md-button>
      </form>
    </div>
    <div v-else-if="realPhase === 'betweenSubmissionAndJudgement'">
      <form @submit.prevent="startJudgementPhase">
        <md-field>
          <label>Correctness.json</label>
          <md-file id="correctnessJSON" required/>
        </md-field>
        <md-button type="submit" :disabled="startingJudgementPhase">Start Judgement Phase</md-button>
      </form>
    </div>
    <div v-else>
      {{ realPhase }}
    </div>
  </div>
</template>

<script>
import IPFSCat from '@/mixins/ipfs-cat.js'

export default {
  name: 'ContestOrganizer',
  mixins: [
    IPFSCat
  ],
  data () {
    return {
      contest: null,
      blockTimestamp: 0,
      createdBlockNumber: 0,
      phase: null,
      timedrift: null,
      announcementPhaseFinishedAt: null,
      submissionPhaseFinishedAt: null,
      prejudgementPhaseFinishedAt: null,
      judgementPhaseFinishedAt: null,
      claimingPhaseFinishedAt: null,
      passphrase: '',
      startingSubmissionPhase: false,
      startingJudgementPhase: false
    }
  },
  computed: {
    realPhase () {
      if (
        !this.blockTimestamp ||
        !this.phase ||
        !this.timedrift ||
        !this.announcementPhaseFinishedAt ||
        !this.submissionPhaseFinishedAt ||
        !this.prejudgementPhaseFinishedAt ||
        !this.judgementPhaseFinishedAt ||
        !this.claimingPhaseFinishedAt
      ) return ''

      if (this.phase.eq(this.$web3.utils.toBN(0))) {
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.announcementPhaseFinishedAt)) return 'announcement'
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.announcementPhaseFinishedAt.add(this.timedrift))) return 'betweenAnnouncementAndSubmission'
        return 'abnormalTermination'
      }
      if (this.phase.eq(this.$web3.utils.toBN(1))) {
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.submissionPhaseFinishedAt)) return 'submission'
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.submissionPhaseFinishedAt.add(this.timedrift))) return 'betweenSubmissionAndJudgement'
        return 'abnormalTermination'
      }
      if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.prejudgementPhaseFinishedAt)) return 'prejudgement'
      if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.judgementPhaseFinishedAt)) return 'judgement'
      if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.claimingPhaseFinishedAt)) return 'claiming'
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
      this.contest.PhaseChanged().on('data', event => this.setPhase(event))

      await Promise.all([
        this.setBlockTimestamp(),
        this.setPhase(),
        this.setTimedrift(),
        this.setAnnouncementPhaseFinishedAt(),
        this.setSubmissionPhaseFinishedAt(),
        this.setPrejudgementPhaseFinishedAt(),
        this.setJudgementPhaseFinishedAt(),
        this.setClaimingPhaseFinishedAt(),
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
    async setPhase (event) {
      if (event) {
        this.phase = this.$web3.utils.toBN(event.returnValues.phase)
      } else {
        this.phase = await this.contest.phase()
      }
    },
    async setTimedrift () {
      this.timedrift = await this.contest.timedrift()
    },
    async setAnnouncementPhaseFinishedAt () {
      this.announcementPhaseFinishedAt = await this.contest.announcementPhaseFinishedAt()
    },
    async setSubmissionPhaseFinishedAt () {
      this.submissionPhaseFinishedAt = await this.contest.submissionPhaseFinishedAt()
    },
    async setPrejudgementPhaseFinishedAt () {
      this.prejudgementPhaseFinishedAt = await this.contest.prejudgementPhaseFinishedAt()
    },
    async setJudgementPhaseFinishedAt () {
      this.judgementPhaseFinishedAt = await this.contest.judgementPhaseFinishedAt()
    },
    async setClaimingPhaseFinishedAt () {
      this.claimingPhaseFinishedAt = await this.contest.claimingPhaseFinishedAt()
    },
    async setPageName () {
      const events = await this.contest.getPastEvents('PhaseChanged', { fromBlock: this.createdBlockNumber })
      const transaction = await this.$web3.eth.getTransaction(events.filter(event => event.returnValues.phase === '0')[0].transactionHash)
      const cid = this.$web3.eth.abi.decodeParameters(this.$ContestsManager.abi[2].inputs, transaction.input.substring(10)).cid
      this.$emit('set-page-name', (await this.ipfsCat(cid + '/name')) + ' Organizer')
    },
    async startSubmissionPhase () {
      this.startingSubmissionPhase = true

      const accounts = await this.$web3.eth.getAccounts()

      await this.contest.startSubmissionPhase(this.passphrase, { from: accounts[0] })

      this.startingSubmissionPhase = false
    },
    async startJudgementPhase () {
      this.startingJudgementPhase = true

      const accounts = await this.$web3.eth.getAccounts()

      const correctnessJSON = await document.getElementById('correctnessJSON').files[0].text()
      const Correctness = this.$contract(JSON.parse(correctnessJSON))
      Correctness.setProvider(this.$web3.currentProvider)
      const correctness = await Correctness.new({ from: accounts[0] })

      await this.contest.startJudgementPhase(correctness.address, { from: accounts[0] })

      this.startingJudgementPhase = false
    }
  }
}
</script>
