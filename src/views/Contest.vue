<template>
  <div>
    <div>
      {{ description }}
    </div>
    <div>
      {{ winner }}
    </div>
    <div v-if="realPhase === 'submission'">
      <form @submit.prevent="submit">
        <md-field>
          <label>Submission.json</label>
          <md-file id="submissionJSONToSubmit" required/>
        </md-field>
        <md-button type="submit" :disabled="!encryptedPresubmissionTesterCC || !passphrase || submitting">Submit</md-button>
      </form>
    </div>
    <div v-else-if="realPhase === 'claim'">
      <form @submit.prevent="claim">
        <md-field>
          <label>Submission.json</label>
          <md-file id="submissionJSONToClaim" required/>
        </md-field>
        <md-button type="submit" :disabled="claiming">Claim</md-button>
      </form>
    </div>
    <div v-else>
      {{ realPhase }}
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
      createdBlockNumber: 0,
      phase: null,
      announcementPhaseFinishedAt: null,
      submissionPhaseFinishedAt: null,
      claimPhaseFinishedAt: null,
      timedrift: null,
      winner: '',
      encryptedDescription: '',
      encryptedPresubmissionTesterCC: '',
      passphrase: '',
      submitting: false,
      claiming: false
    }
  },
  computed: {
    realPhase () {
      if (
        !this.blockTimestamp ||
        !this.phase ||
        !this.announcementPhaseFinishedAt ||
        !this.submissionPhaseFinishedAt ||
        !this.claimPhaseFinishedAt ||
        !this.timedrift
      ) return ''

      if (this.phase.eq(this.$web3.utils.toBN(0))) {
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.announcementPhaseFinishedAt)) return 'announcement'
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.announcementPhaseFinishedAt.add(this.timedrift))) return 'betweenAnnouncementAndSubmission'
        return 'abnormalTermination'
      }
      if (this.phase.eq(this.$web3.utils.toBN(1))) {
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.submissionPhaseFinishedAt)) return 'submission'
        if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.submissionPhaseFinishedAt.add(this.timedrift))) return 'betweenSubmissionAndClaim'
        return 'abnormalTermination'
      }
      if (this.$web3.utils.toBN(this.blockTimestamp).lte(this.claimPhaseFinishedAt)) return 'claim'
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

      await this.setCreatedBlockNumber()

      this.$web3.eth.subscribe('newBlockHeaders').on('data', this.setBlockTimestamp)
      this.contest.PhaseChanged().on('data', event => this.setPhase(event).then(this.setPassphrase))
      this.contest.WinnerChanged().on('data', this.setWinner)

      await Promise.all([
        this.setBlockTimestamp(),
        this.setPhase().then(this.setPassphrase),
        this.setAnnouncementPhaseFinishedAt(),
        this.setSubmissionPhaseFinishedAt(),
        this.setClaimPhaseFinishedAt(),
        this.setTimedrift(),
        this.setWinner(),
        this.setPageNameAndEncryptedDescriptionAndEncryptedPresubmissionTesterCC()
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
    async setAnnouncementPhaseFinishedAt () {
      this.announcementPhaseFinishedAt = await this.contest.announcementPhaseFinishedAt()
    },
    async setSubmissionPhaseFinishedAt () {
      this.submissionPhaseFinishedAt = await this.contest.submissionPhaseFinishedAt()
    },
    async setClaimPhaseFinishedAt () {
      this.claimPhaseFinishedAt = await this.contest.claimPhaseFinishedAt()
    },
    async setTimedrift () {
      this.timedrift = await this.contest.timedrift()
    },
    async setPageNameAndEncryptedDescriptionAndEncryptedPresubmissionTesterCC () {
      const events = await this.contest.getPastEvents('PhaseChanged', { fromBlock: this.createdBlockNumber })
      const transaction = await this.$web3.eth.getTransaction(events.filter(event => event.returnValues.phase === '0')[0].transactionHash)
      const cid = this.$web3.eth.abi.decodeParameters(this.$ContestsManager.abi[2].inputs, transaction.input.substring(10)).cid
      await Promise.all([
        this.setPageName(cid),
        this.setEncryptedDescription(cid),
        this.setEncryptedPresubmissionTesterCC(cid)
      ])
    },
    async setPageName (cid) {
      let name = new Uint8Array()
      for await (const chunk of this.$ipfs.cat('/ipfs/' + cid + '/name')) {
        const newName = new Uint8Array(name.length + chunk.length)
        newName.set(name)
        newName.set(chunk, name.length)
        name = newName
      }
      this.$emit('set-page-name', (new TextDecoder()).decode(name))
    },
    async setEncryptedDescription (cid) {
      let encryptedDescription = new Uint8Array()
      for await (const chunk of this.$ipfs.cat('/ipfs/' + cid + '/encryptedDescription')) {
        const newEncryptedDescription = new Uint8Array(encryptedDescription.length + chunk.length)
        newEncryptedDescription.set(encryptedDescription)
        newEncryptedDescription.set(chunk, encryptedDescription.length)
        encryptedDescription = newEncryptedDescription
      }
      this.encryptedDescription = (new TextDecoder()).decode(encryptedDescription)
    },
    async setEncryptedPresubmissionTesterCC (cid) {
      let encryptedPresubmissionTesterCC = new Uint8Array()
      for await (const chunk of this.$ipfs.cat('/ipfs/' + cid + '/encryptedPresubmissionTesterCC')) {
        const newEncryptedPresubmissionTesterCC = new Uint8Array(encryptedPresubmissionTesterCC.length + chunk.length)
        newEncryptedPresubmissionTesterCC.set(encryptedPresubmissionTesterCC)
        newEncryptedPresubmissionTesterCC.set(chunk, encryptedPresubmissionTesterCC.length)
        encryptedPresubmissionTesterCC = newEncryptedPresubmissionTesterCC
      }
      this.encryptedPresubmissionTesterCC = (new TextDecoder()).decode(encryptedPresubmissionTesterCC)
    },
    async setWinner (event) {
      if (event) {
        this.winner = event.returnValues.winner
      } else {
        this.winner = await this.contest.winner()
      }
    },
    async setPassphrase () {
      if (this.phase.gte(this.$web3.utils.toBN(1)) && !this.passphrase) {
        const events = await this.contest.getPastEvents('PhaseChanged', { fromBlock: this.createdBlockNumber })
        const transaction = await this.$web3.eth.getTransaction(events.filter(event => event.returnValues.phase === '1')[0].transactionHash)
        this.passphrase = this.$web3.eth.abi.decodeParameters(this.$Contest.abi[14].inputs, transaction.input.substring(10)).passphrase
      }
    },
    async submit () {
      this.submitting = true

      const accounts = await this.$web3.eth.getAccounts()

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
      if (presubmissionTesterCR.execResult.exceptionError) throw presubmissionTesterCR.execResult.exceptionError
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
      if (submissionCR.execResult.exceptionError) throw submissionCR.execResult.exceptionError
      const submissionAddress = submissionCR.createdAddress

      const testInput1R = await vm.runCall({
        origin: address,
        caller: address,
        to: presubmissionTesterAddress,
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: Buffer.from(this.$web3.eth.abi.encodeFunctionCall(this.$ITester.abi[0], []).replace(/^0x/, ''), 'hex')
      })
      if (testInput1R.execResult.exceptionError) throw testInput1R.execResult.exceptionError
      const testInput1RV = this.$web3.eth.abi.decodeParameters(this.$ITester.abi[0].outputs, testInput1R.execResult.returnValue.toString('hex'))[0]

      const testOutput1R = await vm.runCall({
        origin: address,
        caller: address,
        to: submissionAddress,
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: Buffer.from(this.$web3.eth.abi.encodeFunctionCall(this.$ISubmission.abi[0], [testInput1RV]).replace(/^0x/, ''), 'hex')
      })
      if (testOutput1R.execResult.exceptionError) throw testOutput1R.execResult.exceptionError
      const testOutput1RV = this.$web3.eth.abi.decodeParameters(this.$ISubmission.abi[0].outputs, testOutput1R.execResult.returnValue.toString('hex'))[0]

      const test1R = await vm.runCall({
        origin: address,
        caller: address,
        to: presubmissionTesterAddress,
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: Buffer.from(this.$web3.eth.abi.encodeFunctionCall(this.$ITester.abi[3], [testOutput1RV]).replace(/^0x/, ''), 'hex')
      })
      if (test1R.execResult.exceptionError) throw test1R.execResult.exceptionError
      const test1RV = this.$web3.eth.abi.decodeParameters(this.$ITester.abi[3].outputs, test1R.execResult.returnValue.toString('hex'))[0]
      if (!test1RV) throw new Error('Presubmission Test Failed')

      const submissionRC = JSON.parse(submissionJSON).deployedBytecode
      await this.contest.submit(this.$web3.utils.soliditySha3(submissionRC, accounts[1]), { from: accounts[1] })

      this.submitting = false
    },
    async claim () {
      this.claiming = true

      const accounts = await this.$web3.eth.getAccounts()

      const submissionJSON = await document.getElementById('submissionJSONToClaim').files[0].text()
      const Submission = this.$contract(JSON.parse(submissionJSON))
      Submission.setProvider(this.$web3.currentProvider)
      const submission = await Submission.new({ from: accounts[1] })

      await this.contest.claim(submission.address, { from: accounts[1] })

      this.claiming = false
    }
  }
}
</script>
