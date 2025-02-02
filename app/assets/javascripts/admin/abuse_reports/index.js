import Vue from 'vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import AbuseReportsApp from './components/app.vue';

export const initAbuseReportsApp = () => {
  const el = document.querySelector('#js-abuse-reports-list-app');

  if (!el) {
    return null;
  }

  const { abuseReportsData } = el.dataset;
  const { reports, pagination } = convertObjectPropsToCamelCase(JSON.parse(abuseReportsData), {
    deep: true,
  });

  return new Vue({
    el,
    render: (createElement) =>
      createElement(AbuseReportsApp, {
        props: {
          abuseReports: reports,
          pagination,
        },
      }),
  });
};
