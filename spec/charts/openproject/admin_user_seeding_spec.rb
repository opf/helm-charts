# frozen_string_literal: true
require 'spec_helper'

describe 'admin user seeder configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  subject { template.dig('Secret/optest-openproject-core', 'stringData') }

  context 'when setting the seeder' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        openproject:
          admin_user:
            name: "Foo Bar"
      YAML
      )
    end

    it 'adds a respective ENV', :aggregate_failures do
      expect(subject)
        .to include("OPENPROJECT_SEED_ADMIN_USER_NAME" => "Foo Bar")

      expect(subject)
        .not_to include("OPENPROJECT_SEED_ADMIN_USER_LOCKED" => "true")
    end
  end

  context 'when setting the admin as locked' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        openproject:
          admin_user:
            locked: true
      YAML
      )
    end

    it 'adds a respective ENV', :aggregate_failures do
      expect(subject)
        .to include("OPENPROJECT_SEED_ADMIN_USER_LOCKED" => "true")
    end
  end

  context 'when leaving defaults' do
    let(:default_values) do
      HelmTemplate.with_defaults({})
    end

    it 'the name is the default', :aggregate_failures do
      expect(subject)
        .to include("OPENPROJECT_SEED_ADMIN_USER_NAME" => "OpenProject Admin")
    end
  end
end
