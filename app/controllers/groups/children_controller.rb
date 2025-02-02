# frozen_string_literal: true

module Groups
  class ChildrenController < Groups::ApplicationController
    extend ::Gitlab::Utils::Override

    before_action :group
    skip_cross_project_access_check :index

    feature_category :subgroups

    # TODO: Set to higher urgency after resolving https://gitlab.com/gitlab-org/gitlab/-/issues/331494
    urgency :low, [:index]

    def index
      params[:sort] ||= @group_projects_sort
      parent = if params[:parent_id].present?
                 GroupFinder.new(current_user).execute(id: params[:parent_id])
               else
                 @group
               end

      if parent.nil?
        render_404
        return
      end

      setup_children(parent)

      respond_to do |format|
        format.json do
          serializer = GroupChildSerializer
                         .new(current_user: current_user)
                         .with_pagination(request, response)
          serializer.expand_hierarchy(parent) if params[:filter].present?
          render json: serializer.represent(@children)
        end
      end
    end

    protected

    def setup_children(parent)
      @children = GroupDescendantsFinder.new(
        current_user: current_user,
        parent_group: parent,
        params: params.to_unsafe_h
      ).execute.page(params[:page])
    end

    private

    override :has_project_list?
    def has_project_list?
      true
    end
  end
end
