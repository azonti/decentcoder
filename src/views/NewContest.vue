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
      <label>Announcement Period Finished at</label>
      <md-input type="datetime-local" required v-model="announcementPeriodFinishedAtDTL"/>
    </md-field>
    <md-field>
      <label>Submission Period Finished at</label>
      <md-input type="datetime-local" required v-model="submissionPeriodFinishedAtDTL"/>
    </md-field>
    <md-field>
      <label>Claim Period Finished at</label>
      <md-input type="datetime-local" required v-model="claimPeriodFinishedAtDTL"/>
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
      announcementPeriodFinishedAtDTL: '',
      submissionPeriodFinishedAtDTL: '',
      claimPeriodFinishedAtDTL: '',
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

      const [
        encryptedDescriptionCIDPath,
        encryptedPresubmissionTesterCCCIDPath,
        postclaimTesterCCHash,
        accounts
      ] = await Promise.all([
        this.getEncryptedDescriptionCIDPathToCreateAndPushNewContest(),
        this.getEncryptedPresubmissionTesterCCCIDPathToCreateAndPushNewContest(),
        this.getPostclaimTesterCCHashToCreateAndPushNewContest(),
        this.$web3.eth.getAccounts()
      ])
      await this.contestsManager.createAndPushNewContest(
        this.name,
        this.$web3.utils.toWei(this.organizerDepositEther),
        this.$dayjs(this.announcementPeriodFinishedAtDTL).unix(),
        this.$dayjs(this.submissionPeriodFinishedAtDTL).unix(),
        this.$dayjs(this.claimPeriodFinishedAtDTL).unix(),
        encryptedDescriptionCIDPath,
        encryptedPresubmissionTesterCCCIDPath,
        postclaimTesterCCHash,
        {
          from: accounts[0],
          value: this.$web3.utils.toBN(this.$web3.utils.toWei(this.organizerDepositEther)).add(this.$web3.utils.toBN(this.$web3.utils.toWei(this.prizeEther)))
        }
      )

      this.creating = false
    },
    async getEncryptedDescriptionCIDPathToCreateAndPushNewContest () {
      const encryptedDescription = this.$CryptoJS.AES.encrypt(this.description, this.passphrase).toString()
      const encryptedDescriptionUnixFSEntry = await this.$ipfs.add(encryptedDescription)
      return encryptedDescriptionUnixFSEntry.cid.toString()
    },
    async getEncryptedPresubmissionTesterCCCIDPathToCreateAndPushNewContest () {
      const presubmissionTesterJSON = await document.getElementById('presubmissionTesterJSON').files[0].text()
      const presubmissionTesterCC = JSON.parse(presubmissionTesterJSON).bytecode
      const encryptedPresubmissionTesterCC = this.$CryptoJS.AES.encrypt(presubmissionTesterCC, this.passphrase).toString()
      const presubmissionTesterUnixFSEntry = await this.$ipfs.add(encryptedPresubmissionTesterCC)
      return presubmissionTesterUnixFSEntry.cid.toString()
    },
    async getPostclaimTesterCCHashToCreateAndPushNewContest () {
      const postclaimTesterJSON = await document.getElementById('postclaimTesterJSON').files[0].text()
      const postclaimTesterCC = JSON.parse(postclaimTesterJSON).bytecode
      return this.$web3.utils.soliditySha3(postclaimTesterCC)
    }
  }
}
</script>
