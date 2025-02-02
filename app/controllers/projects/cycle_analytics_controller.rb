# frozen_string_literal: true

class Projects::CycleAnalyticsController < Projects::ApplicationController
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::TextHelper
  include CycleAnalyticsParams
  include GracefulTimeoutHandling
  include ProductAnalyticsTracking
  extend ::Gitlab::Utils::Override

  before_action :authorize_read_cycle_analytics!
  before_action :load_value_stream, only: :show

  track_custom_event :show,
    name: 'p_analytics_valuestream',
    action: 'perform_analytics_usage_action',
    label: 'redis_hll_counters.analytics.analytics_total_unique_counts_monthly',
    destinations: %i[redis_hll snowplow]

  feature_category :planning_analytics
  urgency :low

  before_action do
    push_licensed_feature(:cycle_analytics_for_groups) if project.licensed_feature_available?(:cycle_analytics_for_groups)
    push_licensed_feature(:group_level_analytics_dashboard) if project.licensed_feature_available?(:group_level_analytics_dashboard)
    push_frontend_feature_flag(:group_analytics_dashboards_page)
  end

  def show
    @cycle_analytics = Analytics::CycleAnalytics::ProjectLevel.new(project: @project, options: options(cycle_analytics_project_params))
    @request_params ||= ::Gitlab::Analytics::CycleAnalytics::RequestParams.new(all_cycle_analytics_params)

    respond_to do |format|
      format.html do
        Gitlab::UsageDataCounters::CycleAnalyticsCounter.count(:views)

        render :show
      end
      format.json do
        render json: cycle_analytics_json
      end
    end
  end

  private

  override :all_cycle_analytics_params
  def all_cycle_analytics_params
    super.merge({ namespace: @project.project_namespace, value_stream: @value_stream })
  end

  def load_value_stream
    @value_stream = Analytics::CycleAnalytics::ValueStream.build_default_value_stream(@project.project_namespace)
  end

  def cycle_analytics_json
    {
      summary: @cycle_analytics.summary,
      stats: @cycle_analytics.stats,
      permissions: @cycle_analytics.permissions(user: current_user)
    }
  end

  def tracking_namespace_source
    project.namespace
  end

  def tracking_project_source
    project
  end
end
