import Vue from 'vue'
import VueRouter from 'vue-router'
import Home from '../views/Home.vue'

Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'Home',
    component: Home
  },
  {
    path: '/about',
    name: 'About',
    // route level code-splitting
    // this generates a separate chunk (about.[hash].js) for this route
    // which is lazy-loaded when the route is visited.
    component: () => import(/* webpackChunkName: "about" */ '../views/About.vue')
  },
  {
    path: '/contests',
    name: 'Contests',
    component: () => import(/* webpackChunkName: "contests" */ '../views/Contests.vue')
  },
  {
    path: '/newContest',
    name: 'New Contest',
    component: () => import(/* webpackChunkName: "newContest" */ '../views/NewContest.vue')
  },
  {
    path: '/contests/:address',
    name: 'Contest',
    component: () => import(/* webpackChunkName: "contest" */ '../views/Contest.vue')
  },
  {
    path: '/contests/:address/organizer',
    name: 'Contest Organizer',
    component: () => import(/* webpackChunkName: "contestOrganizer" */ '../views/ContestOrganizer.vue')
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
