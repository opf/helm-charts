# frozen_string_literal: true
require 'spec_helper'

describe 'hocuspocus probes configuration' do
  let(:template) { HelmTemplate.new(default_values) }
  let(:hocuspocus) { 'Deployment/optest-openproject-hocuspocus' }

  context 'with default configuration' do
    let(:default_values) do
      {}
    end

    it 'defines liveness and readiness probes', :aggregate_failures do
      expect(template.keys).to include hocuspocus

      spec = template.find_container(hocuspocus, 'hocuspocus')
      %w[livenessProbe readinessProbe].each do |probe|
        expect(spec[probe]['httpGet']).to eq('path' => '/', 'port' => 'http')
        expect(spec[probe]['timeoutSeconds']).to eq 5
      end
      expect(spec['livenessProbe']['periodSeconds']).to eq 15
      expect(spec['readinessProbe']['periodSeconds']).to eq 10
    end
  end

  context 'when disabling hocuspocus probes' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        hocuspocus:
          probes:
            enabled: false
      YAML
      )
    end

    it 'does not define probes', :aggregate_failures do
      spec = template.find_container(hocuspocus, 'hocuspocus')
      expect(spec['livenessProbe']).to be_nil
      expect(spec['readinessProbe']).to be_nil
    end
  end

  context 'when disabling the global liveness probe' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        probes:
          liveness:
            enabled: false
      YAML
      )
    end

    it 'only defines the readiness probe', :aggregate_failures do
      spec = template.find_container(hocuspocus, 'hocuspocus')
      expect(spec['livenessProbe']).to be_nil
      expect(spec['readinessProbe']).to be_a(Hash)
    end
  end
end
