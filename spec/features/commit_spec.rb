# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Commit', feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  shared_examples "single commit view" do
    let(:commit) do
      project.repository.commits(nil, limit: 100).find do |commit|
        commit.diffs.size > 1
      end
    end

    let(:files) { commit.diffs.diff_files.to_a }

    before do
      stub_feature_flags(async_commit_diff_files: false)
      project.add_maintainer(user)
      sign_in(user)
    end

    describe "commit details" do
      subject { page }

      before do
        visit project_commit_path(project, commit)
      end

      it "shows the short commit message" do
        expect(page).to have_content(commit.title)
      end

      it "reports the correct number of total changes" do
        expect(page).to have_content("Changes #{commit.diffs.size}")
      end

      it 'renders diff stats', :js do
        expect(page).to have_selector(".diff-stats")
      end

      it_behaves_like 'code highlight'
    end

    describe "pagination" do
      before do
        stub_const("Projects::CommitController::COMMIT_DIFFS_PER_PAGE", 1)

        visit project_commit_path(project, commit)
      end

      it "shows an adjusted count for changed files on this page", :js do
        expect(page).to have_content("Showing 1 changed file")
      end

      it "shows only the first diff on the first page" do
        expect(page).to have_selector(".files ##{files[0].file_hash}")
        expect(page).not_to have_selector(".files ##{files[1].file_hash}")
      end

      it "can navigate to the second page" do
        within(".files .gl-pagination") do
          click_on("2")
        end

        expect(page).not_to have_selector(".files ##{files[0].file_hash}")
        expect(page).to have_selector(".files ##{files[1].file_hash}")
      end
    end
  end

  it_behaves_like "single commit view"

  context "when super sidebar is enabled" do
    before do
      user.update!(use_new_navigation: true)
      stub_feature_flags(super_sidebar_nav: true)
    end

    it_behaves_like "single commit view"
  end
end
