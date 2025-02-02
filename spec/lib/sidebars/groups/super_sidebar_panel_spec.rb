# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::SuperSidebarPanel, feature_category: :navigation do
  let_it_be(:group) { create(:group) }

  let(:user) { group.first_owner }

  let(:context) do
    double("Stubbed context", current_user: user, container: group, group: group).as_null_object # rubocop:disable RSpec/VerifiedDoubles
  end

  subject { described_class.new(context) }

  it 'implements #super_sidebar_context_header' do
    expect(subject.super_sidebar_context_header).to eq(
      {
        title: group.name,
        avatar: group.avatar_url,
        id: group.id
      })
  end

  describe '#renderable_menus' do
    let(:category_menu) do
      [
        Sidebars::StaticMenu,
        Sidebars::Groups::SuperSidebarMenus::PlanMenu,
        Sidebars::Groups::Menus::CiCdMenu,
        (Sidebars::Groups::Menus::SecurityComplianceMenu if Gitlab.ee?),
        Sidebars::Groups::SuperSidebarMenus::OperationsMenu,
        Sidebars::Groups::Menus::ObservabilityMenu,
        (Sidebars::Groups::Menus::AnalyticsMenu if Gitlab.ee?),
        Sidebars::UncategorizedMenu,
        Sidebars::Groups::Menus::SettingsMenu
      ].compact
    end

    it "is exposed as a renderable menu" do
      expect(subject.instance_variable_get(:@menus).map(&:class)).to eq(category_menu)
    end
  end
end
