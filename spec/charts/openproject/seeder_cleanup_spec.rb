# frozen_string_literal: true
require 'spec_helper'

describe 'seeder cleanup configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  let(:definitions) {
    [
      /optest-openproject-seeder/
    ]
  }

  context 'when setting other TTL' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        cleanup:
          deletePodsOnSuccess: true
          deletePodsOnSuccessTimeout: 1234
      YAML
      )
    end

    it 'Populates annotations for all deployments', :aggregate_failures do
      definitions.each do |name|
        expect(template.spec(name)['ttlSecondsAfterFinished']).to eq(1234)
      end
    end
  end

  context 'when disabling deletePodsOnSuccess' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        cleanup:
          deletePodsOnSuccess: false
          deletePodsOnSuccessTimeout: 1234
      YAML
      )
    end

    it 'Populates annotations for all deployments', :aggregate_failures do
      definitions.each do |name|
        expect(template.spec(name)['ttlSecondsAfterFinished']).to be_nil
      end
    end
  end

  context 'when cleaning up' do
    let(:default_values) do
      {}
    end

    it 'Populates defaults for all deployments', :aggregate_failures do
      definitions.each do |name|
        expect(template.spec(name)['ttlSecondsAfterFinished']).to eq(6000)
      end
    end
  end
end
