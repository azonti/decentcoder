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
      <label>Description</label>
      <md-textarea v-model="description"></md-textarea>
    </md-field>
    <md-field>
      <label>PresubmissionTester.json</label>
      <md-file id="presubmissionTesterJSON" required/>
    </md-field>
    <md-field>
      <label>PostclaimTester.json</label>
      <md-file id="postclaimTesterJSON" required/>
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
      description: '',
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
        postclaimTesterRCHash,
        cid
      ] = await Promise.all([
        this.getPostclaimTesterRCHashToCreateAndPushNewContest(),
        this.getCIDToCreateAndPushNewContest()
      ])
      const result = await this.contestsManager.createAndPushNewContest(
        this.$web3.utils.toWei(this.organizerDepositEther),
        this.$dayjs(this.announcementPhaseFinishedAtDTL).unix(),
        this.$dayjs(this.submissionPhaseFinishedAtDTL).unix(),
        this.$dayjs(this.claimPhaseFinishedAtDTL).unix(),
        cid,
        this.$web3.utils.soliditySha3(this.passphrase),
        postclaimTesterRCHash,
        {
          from: accounts[0],
          value: this.$web3.utils.toBN(this.$web3.utils.toWei(this.organizerDepositEther)).add(this.$web3.utils.toBN(this.$web3.utils.toWei(this.prizeEther)))
        }
      )

      this.$router.push('/contests/' + result.logs[0].args.contest + '/organizer')

      this.creating = false
    },
    async getPostclaimTesterRCHashToCreateAndPushNewContest () {
      const postclaimTesterJSON = await document.getElementById('postclaimTesterJSON').files[0].text()
      const postclaimTesterRC = JSON.parse(postclaimTesterJSON).deployedBytecode
      return this.$web3.utils.soliditySha3(postclaimTesterRC)
    },
    async getCIDToCreateAndPushNewContest () {
      const nameFileObject = {
        path: 'tmp/name',
        content: this.name
      }

      const encryptedDescription = this.$CryptoJS.AES.encrypt(this.description, this.passphrase).toString()
      const encryptedDescriptionFileObject = {
        path: 'tmp/encryptedDescription',
        content: encryptedDescription
      }

      const presubmissionTesterJSON = await document.getElementById('presubmissionTesterJSON').files[0].text()
      const presubmissionTesterCC = JSON.parse(presubmissionTesterJSON).bytecode
      const encryptedPresubmissionTesterCC = this.$CryptoJS.AES.encrypt(presubmissionTesterCC, this.passphrase).toString()
      const encryptedPresubmissionTesterCCFileObject = {
        path: 'tmp/encryptedPresubmissionTesterCC',
        content: encryptedPresubmissionTesterCC
      }

      for await (const unixFSEntry of this.$ipfs.addAll([nameFileObject, encryptedDescriptionFileObject, encryptedPresubmissionTesterCCFileObject])) {
        if (unixFSEntry.path === 'tmp') {
          return unixFSEntry.cid.toString()
        }
      }
    }
  }
}
</script>
