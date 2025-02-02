# frozen_string_literal: true

class ForkTargetsFinder
  def initialize(project, user)
    @project = project
    @user = user
  end

  def execute(options = {})
    items = fork_targets(options)

    by_search(items, options)
  end

  private

  attr_reader :project, :user

  def by_search(items, options)
    return items if options[:search].blank?

    items.search(options[:search])
  end

  def fork_targets(options)
    if options[:only_groups]
      user.manageable_groups(include_groups_with_developer_maintainer_access: true)
    else
      user.forkable_namespaces.sort_by_type
    end
  end
end

ForkTargetsFinder.prepend_mod_with('ForkTargetsFinder')
