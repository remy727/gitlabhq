# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::CommitsController, feature_category: :source_code_management do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }

  before do
    project.add_maintainer(user)
  end

  context 'signed in' do
    before do
      sign_in(user)
    end

    describe "GET commits_root" do
      context "no ref is provided" do
        it 'redirects to the default branch of the project' do
          get :commits_root, params: { namespace_id: project.namespace, project_id: project }

          expect(response).to redirect_to project_commits_path(project)
        end
      end
    end

    describe "GET show" do
      render_views

      context 'with file path' do
        before do
          get :show, params: { namespace_id: project.namespace, project_id: project, id: id }
        end

        context "valid branch, valid file" do
          let(:id) { 'master/README.md' }

          it { is_expected.to respond_with(:success) }
        end

        context "valid branch, invalid file" do
          let(:id) { 'master/invalid-path.rb' }

          it { is_expected.to respond_with(:not_found) }
        end

        context "invalid branch, valid file" do
          let(:id) { 'invalid-branch/README.md' }

          it { is_expected.to respond_with(:not_found) }
        end

        context "branch with invalid format, valid file" do
          let(:id) { 'branch with space/README.md' }

          it { is_expected.to respond_with(:not_found) }
        end
      end

      context "with an invalid limit" do
        let(:id) { "master/README.md" }

        it "uses the default limit" do
          expect_any_instance_of(Repository).to receive(:commits).with(
            "master",
            path: "README.md",
            limit: described_class::COMMITS_DEFAULT_LIMIT,
            offset: 0,
            include_referenced_by: ["refs/tags/"]
          ).and_call_original

          get :show, params: { namespace_id: project.namespace, project_id: project, id: id, limit: "foo" }

          expect(response).to be_successful
        end

        context 'when limit is a hash' do
          it 'uses the default limit' do
            expect_any_instance_of(Repository).to receive(:commits).with(
              "master",
              path: "README.md",
              limit: described_class::COMMITS_DEFAULT_LIMIT,
              offset: 0,
              include_referenced_by: ['refs/tags/']
            ).and_call_original

            get :show, params: {
              namespace_id: project.namespace,
              project_id: project,
              id: id,
              limit: { 'broken' => 'value' }
            }

            expect(response).to be_successful
          end
        end
      end

      context 'when the show_tags_on_commits_view flag is disabled' do
        let(:id) { "master/README.md" }

        before do
          stub_feature_flags(show_tags_on_commits_view: false)
        end

        it 'does not use the include_referenced_by option' do
          allow_any_instance_of(Repository).to receive(:commits).and_call_original
          expect_any_instance_of(Repository).not_to receive(:commits).with(
            a_hash_including(include_referenced_by: any_args)).and_call_original

          get :show, params: { namespace_id: project.namespace, project_id: project, id: id }
        end
      end

      context "when the ref name ends in .atom" do
        context "when the ref does not exist with the suffix" do
          before do
            get :show, params: { namespace_id: project.namespace, project_id: project, id: "master.atom" }
          end

          it "renders as atom" do
            expect(response).to be_successful
            expect(response.media_type).to eq('application/atom+xml')
          end

          it 'renders summary with type=html' do
            expect(response.body).to include('<summary type="html">')
          end
        end

        context "when the ref exists with the suffix" do
          before do
            commit = project.repository.commit('master')

            allow_any_instance_of(Repository).to receive(:commit).and_call_original
            allow_any_instance_of(Repository).to receive(:commit).with('master.atom').and_return(commit)

            get :show, params: {
              namespace_id: project.namespace,
              project_id: project,
              id: "master.atom"
            }
          end

          it "renders as HTML" do
            expect(response).to be_successful
            expect(response.media_type).to eq('text/html')
          end
        end

        context 'when the ref does not exist' do
          before do
            get(:show, params: {
              namespace_id: project.namespace,
              project_id: project,
              id: 'unknown.atom'
            })
          end

          it 'returns 404 page' do
            expect(response).to be_not_found
          end
        end
      end

      context 'with markdown cache' do
        it 'preloads markdown cache for commits' do
          expect(Commit).to receive(:preload_markdown_cache!).and_call_original

          get :show, params: { namespace_id: project.namespace, project_id: project, id: 'master/README.md' }
        end
      end
    end

    describe "GET /commits/:id/signatures" do
      render_views

      before do
        expect(::Gitlab::GitalyClient).to receive(:allow_ref_name_caching).and_call_original unless id.include?(' ')

        get :signatures, params: {
          namespace_id: project.namespace,
          project_id: project,
          id: id
        }, format: :json
      end

      context "valid branch" do
        let(:id) { 'master' }

        it { is_expected.to respond_with(:success) }
      end

      context "invalid branch format" do
        let(:id) { 'some branch' }

        it { is_expected.to respond_with(:not_found) }
      end
    end
  end
end
