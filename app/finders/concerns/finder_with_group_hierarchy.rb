# frozen_string_literal: true

# Module to include into finders to provide support for querying for
# objects up and down the group hierarchy.  Extracted from LabelsFinder
#
# Supports params:
#   :group
#   :group_id
#   :include_ancestor_groups
#   :include_descendant_groups
module FinderWithGroupHierarchy
  extend ActiveSupport::Concern

  private

  def item_ids
    raise NotImplementedError
  end

  # Gets redacted array of group ids
  # which can include the ancestors and descendants of the requested group.
  def group_ids_for(group)
    strong_memoize(:group_ids) do
      groups = groups_to_include(group)

      # Because we are sure that all groups are in the same hierarchy tree
      # we can preset root group for all of them to optimize permission checks
      Group.preset_root_ancestor_for(groups)

      # Preloading the max access level for the given groups to avoid N+1 queries
      # during the access check.
      if !skip_authorization && current_user && Feature.enabled?(:preload_max_access_levels_for_labels_finder, group)
        Preloaders::UserMaxAccessLevelInGroupsPreloader.new(groups, current_user).execute
      end

      groups_user_can_read_items(groups).map(&:id)
    end
  end

  def groups_to_include(group)
    groups = [group]

    groups += group.ancestors if include_ancestor_groups?
    groups += group.descendants if include_descendant_groups?

    groups
  end

  def include_ancestor_groups?
    params[:include_ancestor_groups]
  end

  def include_descendant_groups?
    params[:include_descendant_groups]
  end

  def group?
    params[:group].present? || params[:group_id].present?
  end

  def group
    strong_memoize(:group) { params[:group].presence || Group.find(params[:group_id]) }
  end

  def read_permission
    raise NotImplementedError
  end

  def authorized_to_read_item?(item_parent)
    return true if skip_authorization

    Ability.allowed?(current_user, read_permission, item_parent)
  end

  def groups_user_can_read_items(groups)
    DeclarativePolicy.user_scope do
      groups.select { |group| authorized_to_read_item?(group) }
    end
  end
end
