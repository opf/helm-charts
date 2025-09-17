# frozen_string_literal: true
require 'spec_helper'

describe 'relative url root configuration' do
  let(:template) { HelmTemplate.new(default_values) }


  context 'when setting openproject railsRelativeUrlRoot' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        openproject:
          railsRelativeUrlRoot: '/foobar'
      YAML
      )
    end

    it 'adds that as a prefix to the health checks', :aggregate_failures do
      %w[livenessProbe readinessProbe startupProbe].each do |probe|
        path = template.find_container('Deployment/optest-openproject-web', 'openproject').dig(probe, 'httpGet', 'path')
        expect(path).to eq '/foobar/health_checks/default' if path
      end
    end
  end

  context 'when setting no relative URL root' do
    let(:default_values) do
      {}
    end

    it 'adds no prefix', :aggregate_failures do
      %w[livenessProbe readinessProbe startupProbe].each do |probe|
        path = template.find_container('Deployment/optest-openproject-web', 'openproject').dig(probe, 'httpGet', 'path')
        expect(path).to eq '/health_checks/default' if path
      end
    end
  end
end
