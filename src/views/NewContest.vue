<template>
  <form @submit.prevent="createAndPushNewContest">
    <md-field>
      <label>Name</label>
      <md-input type="text" required v-model="name"/>
    </md-field>
    <md-field>
      <label>Organizer's Deposit (in Ether)</label>
      <md-input type="number" step="0.000000000000000001" required v-model="organizerDepositEther"/>
    </md-field>
    <md-field>
      <label>Prize (in Ether)</label>
      <md-input type="number" step="0.000000000000000001" required v-model="prizeEther"/>
    </md-field>
    <md-field>
      <label>Announcement Phase Finished at</label>
      <md-input type="datetime-local" required v-model="announcementPhaseFinishedAtDTL"/>
    </md-field>
    <md-field>
      <label>Submission Phase Finished at</label>
      <md-input type="datetime-local" required v-model="submissionPhaseFinishedAtDTL"/>
    </md-field>
    <md-field>
      <label>Claim Phase Finished at</label>
      <md-input type="datetime-local" required v-model="claimPhaseFinishedAtDTL"/>
    </md-field>
    <md-field>
      <label>Content</label>
      <md-textarea v-model="content"></md-textarea>
    </md-field>
    <md-field>
      <label>LocalCorrectness.json</label>
      <md-file id="localCorrectnessJSON" required/>
    </md-field>
    <md-field>
      <label>Correctness.json</label>
      <md-file id="correctnessJSON" required/>
    </md-field>
    <md-field>
      <label>Passphrase (Keep It in Mind!)</label>
      <md-input type="password" required v-model="passphrase"/>
    </md-field>
    <md-button type="submit" :disabled="!contestsManager || creating">Create New Contest</md-button>
  </form>
</template>

<script>
export default {
  name: 'NewContest',
  data () {
    return {
      contestsManager: null,
      name: '',
      organizerDepositEther: '',
      prizeEther: '',
      announcementPhaseFinishedAtDTL: '',
      submissionPhaseFinishedAtDTL: '',
      claimPhaseFinishedAtDTL: '',
      content: '',
      passphrase: '',
      creating: false
    }
  },
  async mounted () {
    this.contestsManager = await this.$ContestsManager.deployed()
  },
  methods: {
    async createAndPushNewContest () {
      this.creating = true

      const accounts = await this.$web3.eth.getAccounts()

      const [
        correctnessRCHash,
        cid
      ] = await Promise.all([
        this.getCorrectnessRCHashToCreateAndPushNewContest(),
        this.getCIDToCreateAndPushNewContest()
      ])
      const result = await this.contestsManager.createAndPushNewContest(
        this.$web3.utils.toWei(this.organizerDepositEther),
        this.$dayjs(this.announcementPhaseFinishedAtDTL).unix(),
        this.$dayjs(this.submissionPhaseFinishedAtDTL).unix(),
        this.$dayjs(this.claimPhaseFinishedAtDTL).unix(),
        cid,
        this.$web3.utils.soliditySha3(this.passphrase),
        correctnessRCHash,
        {
          from: accounts[0],
          value: this.$web3.utils.toBN(this.$web3.utils.toWei(this.organizerDepositEther)).add(this.$web3.utils.toBN(this.$web3.utils.toWei(this.prizeEther)))
        }
      )

      this.$router.push('/contests/' + result.logs[0].args.contest + '/organizer')

      this.creating = false
    },
    async getCorrectnessRCHashToCreateAndPushNewContest () {
      const correctnessJSON = await document.getElementById('correctnessJSON').files[0].text()
      const correctnessRC = JSON.parse(correctnessJSON).deployedBytecode
      return this.$web3.utils.soliditySha3(correctnessRC)
    },
    async getCIDToCreateAndPushNewContest () {
      const nameFileObject = {
        path: 'tmp/name',
        content: this.name
      }

      const encryptedContent = this.$CryptoJS.AES.encrypt(this.content, this.passphrase).toString()
      const encryptedContentFileObject = {
        path: 'tmp/encryptedContent',
        content: encryptedContent
      }

      const localCorrectnessJSON = await document.getElementById('localCorrectnessJSON').files[0].text()
      const localCorrectnessCC = JSON.parse(localCorrectnessJSON).bytecode
      const encryptedLocalCorrectnessCC = this.$CryptoJS.AES.encrypt(localCorrectnessCC, this.passphrase).toString()
      const encryptedLocalCorrectnessCCFileObject = {
        path: 'tmp/encryptedLocalCorrectnessCC',
        content: encryptedLocalCorrectnessCC
      }

      for await (const unixFSEntry of this.$ipfs.addAll([nameFileObject, encryptedContentFileObject, encryptedLocalCorrectnessCCFileObject])) {
        if (unixFSEntry.path === 'tmp') {
          return unixFSEntry.cid.toString()
        }
      }
    }
  }
}
</script>
