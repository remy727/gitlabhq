# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::StaticMenu, feature_category: :navigation do
  let(:context) { {} }

  subject { described_class.new(context) }

  describe '#serialize_for_super_sidebar' do
    it 'returns flat list of all menu items' do
      subject.add_item(Sidebars::MenuItem.new(title: 'Is active', link: 'foo2', active_routes: { controller: 'fooc' }))
      subject.add_item(Sidebars::MenuItem.new(title: 'Not active', link: 'foo3', active_routes: { controller: 'barc' }))
      subject.add_item(Sidebars::NilMenuItem.new(item_id: 'nil_item'))

      allow(context).to receive(:route_is_active).and_return(->(x) { x[:controller] == 'fooc' })

      expect(subject.serialize_for_super_sidebar).to eq(
        [
          {
            title: "Is active",
            icon: nil,
            link: "foo2",
            is_active: true,
            pill_count: nil
          },
          {
            title: "Not active",
            icon: nil,
            link: "foo3",
            is_active: false,
            pill_count: nil
          }
        ]
      )
    end
  end
end
