<template>
  <div>
    <div>
      {{ description }}
    </div>
    <div>
      {{ winner }}
    </div>
    <div v-if="realPeriod === 'submission'">
      <form @submit.prevent="submit">
        <md-field>
          <label>Submission.json</label>
          <md-file id="submissionJSONToSubmit" required/>
        </md-field>
        <md-button type="submit" :disabled="!encryptedPresubmissionTesterCC || !passphrase || submitting">Submit</md-button>
      </form>
    </div>
    <div v-else-if="realPeriod === 'claim'">
      <form @submit.prevent="claim">
        <md-field>
          <label>Submission.json</label>
          <md-file id="submissionJSONToClaim" required/>
        </md-field>
        <md-button type="submit" :disabled="claiming">Claim</md-button>
      </form>
    </div>
    <div v-else>
      {{ realPeriod }}
    </div>
  </div>
</template>

<script>
export default {
  name: 'Contest',
  data () {
    return {
      contest: null,
      blockTimestamp: 0,
      period: null,
      announcementPeriodFinish: null,
      submissionPeriodFinish: null,
      claimPeriodFinish: null,
      timedrift: null,
      encryptedDescription: '',
      encryptedPresubmissionTesterCC: '',
      passphrase: '',
      winner: '',
      submitting: false,
      claiming: false
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
    },
    description () {
      if (
        !this.encryptedDescription ||
        !this.passphrase
      ) return ''

      return this.$CryptoJS.AES.decrypt(this.encryptedDescription, this.passphrase).toString(this.$CryptoJS.enc.Utf8)
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
      this.contest.PeriodChanged().on('data', r => this.setPeriodAndPassphrase(r.returnValues.period))
      this.contest.WinnerChanged().on('data', r => this.setWinner(r.returnValues.winner))

      await Promise.all([
        this.contest.name().then(this.setPageName),
        this.$web3.eth.getBlock('latest').then(this.setBlockTimestamp),
        this.contest.period().then(this.setPeriodAndPassphrase),
        this.contest.announcementPeriodFinish().then(this.setAnnouncementPeriodFinish),
        this.contest.submissionPeriodFinish().then(this.setSubmissionPeriodFinish),
        this.contest.claimPeriodFinish().then(this.setClaimPeriodFinish),
        this.contest.timedrift().then(this.setTimedrift),
        this.contest.encryptedDescriptionCIDPath().then(this.setEncryptedDescription),
        this.contest.encryptedPresubmissionTesterCCCIDPath().then(this.setEncryptedPresubmissionTesterCC),
        this.contest.winner().then(this.setWinner)
      ])
    },
    setPageName (pageName) {
      this.$emit('set-page-name', pageName)
    },
    setBlockTimestamp (blockHeader) {
      this.blockTimestamp = blockHeader.timestamp
    },
    async setPeriodAndPassphrase (period) {
      if (this.$web3.utils.isBN(period)) {
        this.period = period
      } else {
        this.period = this.$web3.utils.toBN(period)
      }
      if (this.period.gte(this.$web3.utils.toBN(1))) {
        this.passphrase = await this.contest.passphrase()
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
    async setEncryptedDescription (encryptedDescriptionCIDPath) {
      let encryptedDescription = ''
      const decoder = new TextDecoder()
      for await (const chunk of this.$ipfs.cat('/ipfs/' + encryptedDescriptionCIDPath)) {
        encryptedDescription += decoder.decode(chunk)
      }
      this.encryptedDescription = encryptedDescription
    },
    async setEncryptedPresubmissionTesterCC (encryptedPresubmissionTesterCCCIDPath) {
      let encryptedPresubmissionTesterCC = ''
      const decoder = new TextDecoder()
      for await (const chunk of this.$ipfs.cat('/ipfs/' + encryptedPresubmissionTesterCCCIDPath)) {
        encryptedPresubmissionTesterCC += decoder.decode(chunk)
      }
      this.encryptedPresubmissionTesterCC = encryptedPresubmissionTesterCC
    },
    setWinner (winner) {
      this.winner = winner
    },
    async submit () {
      this.submitting = true

      const privateKey = Buffer.from('e331b6d69882b4cb4ea581d88e0b604039a3de5967688d3dcffdd2270c0fd109', 'hex')
      const address = this.$EthereumJS.Address.fromPrivateKey(privateKey)
      const account = this.$EthereumJS.Account.fromAccountData({
        balance: this.$web3.utils.toBN('1000000000000000000'),
        nonce: 0
      })
      const vm = new this.$EthereumJS.VM()
      await vm.stateManager.putAccount(address, account)

      const presubmissionTesterCC = this.$CryptoJS.AES.decrypt(this.encryptedPresubmissionTesterCC, this.passphrase).toString(this.$CryptoJS.enc.Utf8)
      const presubmissionTesterCTX = this.$EthereumJS.Transaction.fromTxData({
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: presubmissionTesterCC,
        nonce: 0
      }).sign(privateKey)
      const presubmissionTesterCR = await vm.runTx({ tx: presubmissionTesterCTX })
      if (presubmissionTesterCR.execResult.exceptionError) {
        throw presubmissionTesterCR.execResult.exceptionError
      }
      const presubmissionTesterAddress = presubmissionTesterCR.createdAddress

      const submissionJSON = await document.getElementById('submissionJSONToSubmit').files[0].text()
      const submissionCC = JSON.parse(submissionJSON).bytecode
      const submissionCTX = this.$EthereumJS.Transaction.fromTxData({
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: submissionCC,
        nonce: 1
      }).sign(privateKey)
      const submissionCR = await vm.runTx({ tx: submissionCTX })
      if (submissionCR.execResult.exceptionError) {
        throw submissionCR.execResult.exceptionError
      }
      const submissionAddress = submissionCR.createdAddress

      const testR = await vm.runCall({
        origin: address,
        caller: address,
        to: presubmissionTesterAddress,
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: Buffer.from(this.$web3.eth.abi.encodeFunctionCall(this.$ITester.abi[0], [submissionAddress.toString()]).replace(/^0x/, ''), 'hex')
      })
      if (testR.execResult.exceptionError) {
        throw testR.execResult.exceptionError
      }
      const testRV = this.$web3.eth.abi.decodeParameters(this.$ITester.abi[0].outputs, testR.execResult.returnValue.toString('hex'))
      if (!testRV.passed) {
        throw new Error('Presubmission Test Failed')
      }

      const accounts = await this.$web3.eth.getAccounts()
      await this.contest.submit(this.$web3.utils.soliditySha3(submissionCC, accounts[1]), { from: accounts[1] })

      this.submitting = false
    },
    async claim () {
      this.claiming = true

      const submissionJSON = await document.getElementById('submissionJSONToClaim').files[0].text()
      const submissionCC = JSON.parse(submissionJSON).bytecode

      const accounts = await this.$web3.eth.getAccounts()
      await this.contest.claim(submissionCC, { from: accounts[1] })

      this.claiming = false
    }
  }
}
</script>
