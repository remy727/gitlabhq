import Vue from 'vue';
import { initStatusTriggers } from '../header';
import {
  bindSuperSidebarCollapsedEvents,
  initSuperSidebarCollapsedState,
} from './super_sidebar_collapsed_state_manager';
import SuperSidebar from './components/super_sidebar.vue';

export const initSuperSidebar = () => {
  const el = document.querySelector('.js-super-sidebar');

  if (!el) return false;

  bindSuperSidebarCollapsedEvents();
  initSuperSidebarCollapsedState();

  const { rootPath, sidebar, toggleNewNavEndpoint } = el.dataset;

  return new Vue({
    el,
    name: 'SuperSidebarRoot',
    provide: {
      rootPath,
      toggleNewNavEndpoint,
    },
    render(h) {
      return h(SuperSidebar, {
        props: {
          sidebarData: JSON.parse(sidebar),
        },
      });
    },
  });
};

requestIdleCallback(initStatusTriggers);
