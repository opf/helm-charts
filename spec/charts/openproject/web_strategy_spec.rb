# frozen_string_literal: true
require 'spec_helper'

describe 'setting strategy for web deployment' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when setting custom strategy' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        strategy:
          type: RollingUpdate
          rollingUpdate:
            maxSurge: 30%
            maxUnavailable: 30%
      YAML
      )
    end

    it 'sets that strategy ', :aggregate_failures do
      strategy = template.dig('Deployment/optest-openproject-web', 'spec', 'strategy')
      expect(strategy["type"]).to eq "RollingUpdate"
      expect(strategy["rollingUpdate"]).to include("maxSurge" => "30%", "maxUnavailable" => "30%")
    end
  end

  context 'when setting no strategy' do
    let(:default_values) do
      {}
    end

    it 'Creates the default worker', :aggregate_failures do
      strategy = template.dig('Deployment/optest-openproject-web', 'spec', 'strategy')
      expect(strategy["type"]).to eq "Recreate"
      expect(strategy["rollingUpdate"]).to be_nil
    end
  end
end
