<template>
  <div id="app">
    <md-app md-mode="fixed">
      <md-app-toolbar class="md-primary">
        <md-button class="md-icon-button" @click="menuVisible = !menuVisible">
          <md-icon>menu</md-icon>
        </md-button>
        <span class="md-title">{{ title }}</span>
      </md-app-toolbar>

      <md-app-drawer :md-active.sync="menuVisible">
        <md-list>
          <md-list-item to="/" exact>
            <md-icon>home</md-icon>
            <span class="md-list-item-text">Home</span>
          </md-list-item>
          <md-list-item to="/about" exact>
            <md-icon>info</md-icon>
            <span class="md-list-item-text">About</span>
          </md-list-item>
          <md-list-item to="/contests" exact>
            <md-icon>cake</md-icon>
            <span class="md-list-item-text">Contests</span>
          </md-list-item>
        </md-list>
      </md-app-drawer>

      <md-app-content>
        <router-view @set-page-name="setPageName"/>
      </md-app-content>
    </md-app>
  </div>
</template>

<script>
export default {
  name: 'App',
  data () {
    return {
      menuVisible: false,
      pageName: ''
    }
  },
  computed: {
    title () {
      if (!this.pageName) return 'DecentCoder'

      return 'DecentCoder - ' + this.pageName
    }
  },
  mounted () {
    this.initialize()
  },
  watch: {
    $route () {
      this.initialize()
    }
  },
  methods: {
    initialize () {
      this.setPageName(this.$route.name)
    },
    setPageName (pageName) {
      this.pageName = pageName
    }
  }
}
</script>

<style>
.md-app {
   height: 100vh;
}
</style>
