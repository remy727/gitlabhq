# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Profiles::SavedRepliesController, feature_category: :user_profile do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'GET #index' do
    describe 'feature flag disabled' do
      before do
        stub_feature_flags(saved_replies: false)

        get '/-/profile/saved_replies'
      end

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    describe 'feature flag enabled' do
      before do
        get '/-/profile/saved_replies'
      end

      it { expect(response).to have_gitlab_http_status(:ok) }

      it 'sets hide search settings ivar' do
        expect(assigns(:hide_search_settings)).to eq(true)
      end
    end
  end
end
