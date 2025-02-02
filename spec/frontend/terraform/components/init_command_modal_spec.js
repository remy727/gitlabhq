import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import InitCommandModal from '~/terraform/components/init_command_modal.vue';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';

const accessTokensPath = '/path/to/access-tokens-page';
const terraformApiUrl = 'https://gitlab.com/api/v4/projects/1';
const username = 'username';
const modalId = 'fake-modal-id';
const stateName = 'aws/eu-central-1';
const stateNameEncoded = encodeURIComponent(stateName);
const modalInfoCopyStr = `export GITLAB_ACCESS_TOKEN=<YOUR-ACCESS-TOKEN>
terraform init \\
    -backend-config="address=${terraformApiUrl}/${stateNameEncoded}" \\
    -backend-config="lock_address=${terraformApiUrl}/${stateNameEncoded}/lock" \\
    -backend-config="unlock_address=${terraformApiUrl}/${stateNameEncoded}/lock" \\
    -backend-config="username=${username}" \\
    -backend-config="password=$GITLAB_ACCESS_TOKEN" \\
    -backend-config="lock_method=POST" \\
    -backend-config="unlock_method=DELETE" \\
    -backend-config="retry_wait_min=5"
    `;

describe('InitCommandModal', () => {
  let wrapper;

  const propsData = {
    modalId,
    stateName,
  };
  const provideData = {
    accessTokensPath,
    terraformApiUrl,
    username,
  };

  const findExplanatoryText = () => wrapper.findByTestId('init-command-explanatory-text');
  const findLink = () => wrapper.findComponent(GlLink);
  const findInitCommand = () => wrapper.findByTestId('terraform-init-command');
  const findCopyButton = () => wrapper.findComponent(ModalCopyButton);

  beforeEach(() => {
    wrapper = shallowMountExtended(InitCommandModal, {
      propsData,
      provide: provideData,
      stubs: {
        GlSprintf,
      },
    });
  });

  describe('on rendering', () => {
    it('renders the explanatory text', () => {
      expect(findExplanatoryText().text()).toContain('personal access token');
    });

    it('renders the personal access token link', () => {
      expect(findLink().attributes('href')).toBe(accessTokensPath);
    });

    describe('init command', () => {
      it('includes correct address', () => {
        expect(findInitCommand().text()).toContain(
          `-backend-config="address=${terraformApiUrl}/${stateNameEncoded}"`,
        );
      });
      it('includes correct username', () => {
        expect(findInitCommand().text()).toContain(`-backend-config="username=${username}"`);
      });
    });

    it('renders the copyToClipboard button', () => {
      expect(findCopyButton().exists()).toBe(true);
    });
  });

  describe('when copy button is clicked', () => {
    it('copies init command to clipboard', () => {
      expect(findCopyButton().props('text')).toBe(modalInfoCopyStr);
    });
  });
});
