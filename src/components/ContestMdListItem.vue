<template>
  <md-list-item :to="'/contests/' + address">
      <md-icon>cake</md-icon>
      <div class="md-list-item-text">
        <span>{{ name }}</span>
        <span>by {{ organizer }}</span>
      </div>
  </md-list-item>
</template>

<script>
export default {
  name: 'ContestMdListItem',
  props: {
    address: String
  },
  data () {
    return {
      contest: null,
      name: '',
      organizer: ''
    }
  },
  async mounted () {
    this.contest = await this.$Contest.at(this.address)

    await Promise.all([
      this.contest.name().then(this.setName),
      this.contest.organizer().then(this.setOrganizer)
    ])
  },
  methods: {
    setName (name) {
      this.name = name
    },
    setOrganizer (organizer) {
      this.organizer = organizer
    }
  }
}
</script>
