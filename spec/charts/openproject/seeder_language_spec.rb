# frozen_string_literal: true
require 'spec_helper'

describe 'seeder language configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  subject { template.dig('Secret/optest-openproject-core', 'stringData') }

  context 'when setting seed_locale' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        openproject:
          seed_locale: "de"
      YAML
      )
    end

    it 'sets OPENPROJECT_SEED_LOCALE', :aggregate_failures do
      expect(subject)
        .to include("OPENPROJECT_SEED_LOCALE" => "de")
    end
  end

  context 'when not setting seed_locale' do
    let(:default_values) { {} }

    it 'does not set OPENPROJECT_SEED_LOCALE', :aggregate_failures do
      expect(subject)
        .not_to include("OPENPROJECT_SEED_LOCALE" => anything)
    end
  end
end
