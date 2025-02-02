# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GPG signed commits', feature_category: :source_code_management do
  let(:project) { create(:project, :public, :repository) }

  it 'changes from unverified to verified when the user changes their email to match the gpg key', :sidekiq_might_not_need_inline do
    ref = GpgHelpers::SIGNED_AND_AUTHORED_SHA
    user = create(:user, email: 'unrelated.user@example.org')

    perform_enqueued_jobs do
      create :gpg_key, key: GpgHelpers::User1.public_key, user: user
      user.reload # necessary to reload the association with gpg_keys
    end

    visit project_commit_path(project, ref)

    expect(page).to have_selector('.gl-badge', text: 'Unverified')

    # user changes their email which makes the gpg key verified
    perform_enqueued_jobs do
      user.skip_reconfirmation!
      user.update!(email: GpgHelpers::User1.emails.first)
    end

    visit project_commit_path(project, ref)

    expect(page).to have_selector('.gl-badge', text: 'Verified')
  end

  it 'changes from unverified to verified when the user adds the missing gpg key', :sidekiq_might_not_need_inline do
    ref = GpgHelpers::SIGNED_AND_AUTHORED_SHA
    user = create(:user, email: GpgHelpers::User1.emails.first)

    visit project_commit_path(project, ref)

    expect(page).to have_selector('.gl-badge', text: 'Unverified')

    # user adds the gpg key which makes the signature valid
    perform_enqueued_jobs do
      create :gpg_key, key: GpgHelpers::User1.public_key, user: user
    end

    visit project_commit_path(project, ref)

    expect(page).to have_selector('.gl-badge', text: 'Verified')
  end

  context 'shows popover badges', :js do
    let(:user_1) do
      create :user, email: GpgHelpers::User1.emails.first, username: 'nannie.bernhard', name: 'Nannie Bernhard'
    end

    let(:user_1_key) do
      perform_enqueued_jobs do
        create :gpg_key, key: GpgHelpers::User1.public_key, user: user_1
      end
    end

    let(:user_2) do
      create(:user, email: GpgHelpers::User2.emails.first, username: 'bette.cartwright', name: 'Bette Cartwright').tap do |user|
        # secondary, unverified email
        create :email, user: user, email: 'mail@koffeinfrei.org'
      end
    end

    let(:user_2_key) do
      perform_enqueued_jobs do
        create :gpg_key, key: GpgHelpers::User2.public_key, user: user_2
      end
    end

    it 'unverified signature' do
      visit project_commit_path(project, GpgHelpers::SIGNED_COMMIT_SHA)
      wait_for_all_requests

      page.find('.gl-badge', text: 'Unverified').click

      within '.popover' do
        expect(page).to have_content 'This commit was signed with an unverified signature.'
        expect(page).to have_content "GPG Key ID: #{GpgHelpers::User2.primary_keyid}"
      end
    end

    it 'unverified signature: gpg key email does not match the committer_email but is the same user when the committer_email belongs to the user as a confirmed secondary email' do
      user_2_key
      user_2.emails.find_by(email: 'mail@koffeinfrei.org').confirm

      visit project_commit_path(project, GpgHelpers::SIGNED_COMMIT_SHA)
      wait_for_all_requests

      page.find('.gl-badge', text: 'Unverified').click

      within '.popover' do
        expect(page).to have_content 'This commit was signed with a verified signature, but the committer email is not associated with the GPG Key.'
        expect(page).to have_content "GPG Key ID: #{GpgHelpers::User2.primary_keyid}"
      end
    end

    it 'unverified signature: gpg key email does not match the committer_email when the committer_email belongs to the user as a unconfirmed secondary email' do
      user_2_key

      visit project_commit_path(project, GpgHelpers::SIGNED_COMMIT_SHA)
      wait_for_all_requests

      page.find('.gl-badge', text: 'Unverified').click

      within '.popover' do
        expect(page).to have_content "This commit was signed with a different user's verified signature."
        expect(page).to have_content "GPG Key ID: #{GpgHelpers::User2.primary_keyid}"
      end
    end

    it 'unverified signature: commit contains multiple GPG signatures' do
      user_1_key

      visit project_commit_path(project, GpgHelpers::MULTIPLE_SIGNATURES_SHA)
      wait_for_all_requests

      page.find('.gl-badge', text: 'Unverified').click

      within '.popover' do
        expect(page).to have_content "This commit was signed with multiple signatures."
      end
    end

    it 'verified and the gpg user has a gitlab profile' do
      user_1_key

      visit project_commit_path(project, GpgHelpers::SIGNED_AND_AUTHORED_SHA)
      wait_for_all_requests

      page.find('.gl-badge', text: 'Verified').click

      within '.popover' do
        expect(page).to have_content 'This commit was signed with a verified signature and the committer email was verified to belong to the same user.'
        expect(page).to have_content "GPG Key ID: #{GpgHelpers::User1.primary_keyid}"
      end
    end

    it "verified and the gpg user's profile doesn't exist anymore" do
      user_1_key

      visit project_commit_path(project, GpgHelpers::SIGNED_AND_AUTHORED_SHA)
      wait_for_all_requests

      # wait for the signature to get generated
      expect(page).to have_selector('.gl-badge', text: 'Verified')

      user_1.destroy!

      refresh
      wait_for_all_requests

      page.find('.gl-badge', text: 'Verified').click

      within '.popover' do
        expect(page).to have_content 'This commit was signed with a verified signature and the committer email was verified to belong to the same user.'
        expect(page).to have_content "GPG Key ID: #{GpgHelpers::User1.primary_keyid}"
      end
    end
  end

  context 'view signed commit on the tree view', :js do
    shared_examples 'a commit with a signature' do
      before do
        visit project_tree_path(project, 'signed-commits')
        wait_for_all_requests
      end

      it 'displays commit signature' do
        expect(page).to have_selector('.gl-badge', text: 'Unverified')

        page.find('.gl-badge', text: 'Unverified').click

        within '.popover' do
          expect(page).to have_content 'This commit was signed with multiple signatures.'
        end
      end
    end

    context 'with vue tree view enabled' do
      it_behaves_like 'a commit with a signature'
    end
  end
end
