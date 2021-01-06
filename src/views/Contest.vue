<template>
  <div>
    <div>
      {{ content }}
    </div>
    <div>
      {{ winner }}
    </div>
    <div v-if="realPhase === 'submission'">
      <form @submit.prevent="submit">
        <md-field>
          <label>Answer.json</label>
          <md-file id="answerJSONToSubmit" required/>
        </md-field>
        <md-button type="submit" :disabled="!encryptedLocalCorrectnessCC || !passphrase || submitting">Submit</md-button>
      </form>
    </div>
    <div v-else-if="realPhase === 'judgement'">
      <form @submit.prevent="judge">
        <md-field>
          <label>Answer.json</label>
          <md-file id="answerJSONToJudge" required/>
        </md-field>
        <md-button type="submit" :disabled="judging">Judge</md-button>
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
  name: 'Contest',
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
      winner: '',
      encryptedContent: '',
      encryptedLocalCorrectnessCC: '',
      passphrase: '',
      submitting: false,
      judging: false
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
    },
    content () {
      if (
        !this.encryptedContent ||
        !this.passphrase
      ) return ''

      return this.$CryptoJS.AES.decrypt(this.encryptedContent, this.passphrase).toString(this.$CryptoJS.enc.Utf8)
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
        this.setTimedrift(),
        this.setAnnouncementPhaseFinishedAt(),
        this.setSubmissionPhaseFinishedAt(),
        this.setPrejudgementPhaseFinishedAt(),
        this.setJudgementPhaseFinishedAt(),
        this.setClaimingPhaseFinishedAt(),
        this.setWinner(),
        this.setPageNameAndEncryptedContentAndEncryptedLocalCorrectnessCC()
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
    async setWinner (event) {
      if (event) {
        this.winner = event.returnValues.winner
      } else {
        this.winner = await this.contest.winner()
      }
    },
    async setPageNameAndEncryptedContentAndEncryptedLocalCorrectnessCC () {
      const events = await this.contest.getPastEvents('PhaseChanged', { fromBlock: this.createdBlockNumber })
      const transaction = await this.$web3.eth.getTransaction(events.filter(event => event.returnValues.phase === '0')[0].transactionHash)
      const cid = this.$web3.eth.abi.decodeParameters(this.$ContestsManager.abi[2].inputs, transaction.input.substring(10)).cid
      await Promise.all([
        this.setPageName(cid),
        this.setEncryptedContent(cid),
        this.setEncryptedLocalCorrectnessCC(cid)
      ])
    },
    async setPageName (cid) {
      this.$emit('set-page-name', await this.ipfsCat(cid + '/name'))
    },
    async setEncryptedContent (cid) {
      this.encryptedContent = await this.ipfsCat(cid + '/encryptedContent')
    },
    async setEncryptedLocalCorrectnessCC (cid) {
      this.encryptedLocalCorrectnessCC = await this.ipfsCat(cid + '/encryptedLocalCorrectnessCC')
    },
    async setPassphrase () {
      if (this.phase.gte(this.$web3.utils.toBN(1)) && !this.passphrase) {
        const events = await this.contest.getPastEvents('PhaseChanged', { fromBlock: this.createdBlockNumber })
        const transaction = await this.$web3.eth.getTransaction(events.filter(event => event.returnValues.phase === '1')[0].transactionHash)
        this.passphrase = this.$web3.eth.abi.decodeParameters(this.$Contest.abi[18].inputs, transaction.input.substring(10)).passphrase
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

      const localCorrectnessCC = this.$CryptoJS.AES.decrypt(this.encryptedLocalCorrectnessCC, this.passphrase).toString(this.$CryptoJS.enc.Utf8)
      const localCorrectnessCTX = this.$EthereumJS.Transaction.fromTxData({
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: localCorrectnessCC,
        nonce: 0
      }).sign(privateKey)
      const localCorrectnessCR = await vm.runTx({ tx: localCorrectnessCTX })
      if (localCorrectnessCR.execResult.exceptionError) throw localCorrectnessCR.execResult.exceptionError
      const localCorrectnessAddress = localCorrectnessCR.createdAddress

      const answerJSON = await document.getElementById('answerJSONToSubmit').files[0].text()
      const answerCC = JSON.parse(answerJSON).bytecode
      const answerCTX = this.$EthereumJS.Transaction.fromTxData({
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: answerCC,
        nonce: 1
      }).sign(privateKey)
      const answerCR = await vm.runTx({ tx: answerCTX })
      if (answerCR.execResult.exceptionError) throw answerCR.execResult.exceptionError
      const answerAddress = answerCR.createdAddress

      const testGasLimitR = await vm.runCall({
        origin: address,
        caller: address,
        to: localCorrectnessAddress,
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: Buffer.from(this.$web3.eth.abi.encodeFunctionCall(this.$ICorrectness.abi[6], []).replace(/^0x/, ''), 'hex')
      })
      if (testGasLimitR.execResult.exceptionError) throw testGasLimitR.execResult.exceptionError
      const testGasLimit = this.$web3.eth.abi.decodeParameters(this.$ICorrectness.abi[6].outputs, testGasLimitR.execResult.returnValue.toString('hex'))[0]

      await Promise.all([
        this.testLocallyToSubmit(address, vm, localCorrectnessAddress, answerAddress, testGasLimit, 1),
        this.testLocallyToSubmit(address, vm, localCorrectnessAddress, answerAddress, testGasLimit, 2),
        this.testLocallyToSubmit(address, vm, localCorrectnessAddress, answerAddress, testGasLimit, 3)
      ])

      const answerRC = JSON.parse(answerJSON).deployedBytecode
      await Promise.all(accounts.slice(1).map(account => this.contest.submit(this.$web3.utils.soliditySha3(this.$web3.utils.soliditySha3(answerRC), account), { from: account })))

      this.submitting = false
    },
    async testLocallyToSubmit (address, vm, localCorrectnessAddress, answerAddress, testGasLimit, testNumber) {
      const testInputR = await vm.runCall({
        origin: address,
        caller: address,
        to: localCorrectnessAddress,
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: Buffer.from(this.$web3.eth.abi.encodeFunctionCall(this.$ICorrectness.abi[testNumber - 1], []).replace(/^0x/, ''), 'hex')
      })
      if (testInputR.execResult.exceptionError) throw testInputR.execResult.exceptionError
      const testInput = this.$web3.eth.abi.decodeParameters(this.$ICorrectness.abi[testNumber - 1].outputs, testInputR.execResult.returnValue.toString('hex'))[0]

      const testOutputR = await vm.runCall({
        origin: address,
        caller: address,
        to: answerAddress,
        value: 0,
        gasLimit: this.$web3.utils.toBN(testGasLimit),
        gasPrice: 1,
        data: Buffer.from(this.$web3.eth.abi.encodeFunctionCall(this.$IAnswer.abi[0], [testInput]).replace(/^0x/, ''), 'hex')
      })
      if (testOutputR.execResult.exceptionError) throw testOutputR.execResult.exceptionError
      const testOutput = this.$web3.eth.abi.decodeParameters(this.$IAnswer.abi[0].outputs, testOutputR.execResult.returnValue.toString('hex'))[0]

      const testR = await vm.runCall({
        origin: address,
        caller: address,
        to: localCorrectnessAddress,
        value: 0,
        gasLimit: this.$web3.utils.toBN('10000000000000000'),
        gasPrice: 1,
        data: Buffer.from(this.$web3.eth.abi.encodeFunctionCall(this.$ICorrectness.abi[testNumber + 2], [testOutput]).replace(/^0x/, ''), 'hex')
      })
      if (testR.execResult.exceptionError) throw testR.execResult.exceptionError
      const test = this.$web3.eth.abi.decodeParameters(this.$ICorrectness.abi[testNumber + 2].outputs, testR.execResult.returnValue.toString('hex'))[0]
      if (!test) throw new Error('Your answer is wrong')
    },
    async judge () {
      this.judging = true

      const accounts = await this.$web3.eth.getAccounts()

      const answerJSON = await document.getElementById('answerJSONToJudge').files[0].text()
      const Answer = this.$contract(JSON.parse(answerJSON))
      Answer.setProvider(this.$web3.currentProvider)
      const answer = await Answer.new({ from: accounts[1] })

      await Promise.all(accounts.slice(1).map(account => this.contest.judge(answer.address, { from: account })))

      this.judging = false
    }
  }
}
</script>
