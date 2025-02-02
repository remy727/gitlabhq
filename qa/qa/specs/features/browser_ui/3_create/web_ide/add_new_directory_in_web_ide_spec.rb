# frozen_string_literal: true

# TODO: remove this test when 'vscode_web_ide' feature flag is default enabled
module QA
  RSpec.describe 'Create', :skip_live_env, product_group: :editor do
    describe 'Add a directory in Web IDE' do
      let(:project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'add-directory-project'
          project.initialize_with_readme = true
        end
      end

      before do
        Flow::Login.sign_in
        project.visit!
      end

      context 'when a directory with the same name already exists' do
        let(:directory_name) { 'first_directory' }

        before do
          Resource::Repository::Commit.fabricate_via_api! do |commit|
            commit.project = project
            commit.add_files(
              [
                {
                  file_path: 'first_directory/test_file.txt',
                  content: "Test file content"
                }
              ])
          end

          project.visit!

          Page::Project::Show.perform(&:open_web_ide!)
        end

        it 'throws an error', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347733' do
          Page::Project::WebIDE::Edit.perform do |ide|
            # Support::Waiter.wait_until(sleep_interval: 2, max_duration: 60, reload_page: page,
            # retry_on_exception: true) do
            #   expect(ide).to have_element(:commit_mode_tab)
            # end
            ide.wait_until_ide_loads
            ide.add_directory(directory_name)
          end

          expect(page).to have_content('The name "first_directory" is already taken in this directory.')
        end
      end

      context 'when user adds a new empty directory' do
        let(:directory_name) { 'new_empty_directory' }

        before do
          Page::Project::Show.perform(&:open_web_ide!)
        end

        it 'shows in the tree view but cannot be committed', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347732' do
          Page::Project::WebIDE::Edit.perform do |ide|
            ide.wait_until_ide_loads
            ide.add_directory(directory_name)

            expect(ide).to have_file(directory_name)
            expect(ide).to have_folder_icon(directory_name)
            expect(ide).not_to have_file_addition_icon(directory_name)

            ide.switch_to_commit_tab

            expect(ide).not_to have_file_to_commit(directory_name)
          end
        end
      end
    end
  end
end
