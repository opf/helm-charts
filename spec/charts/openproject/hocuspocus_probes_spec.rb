# frozen_string_literal: true
require 'spec_helper'

describe 'hocuspocus probes configuration' do
  let(:template) { HelmTemplate.new(default_values) }
  let(:hocuspocus) { 'Deployment/optest-openproject-hocuspocus' }

  context 'with default configuration' do
    let(:default_values) { {} }

    it 'defines liveness and readiness probes', :aggregate_failures do
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

  context 'when overriding probe settings for hocuspocus' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        probes:
          liveness:
            initialDelaySeconds: 20
        hocuspocus:
          probes:
            liveness:
              initialDelaySeconds: 0
              periodSeconds: 30
            readiness:
              enabled: false
      YAML
      )
    end

    it 'merges the overrides over the global settings', :aggregate_failures do
      spec = template.find_container(hocuspocus, 'hocuspocus')
      expect(spec['livenessProbe']['initialDelaySeconds']).to eq 0
      expect(spec['livenessProbe']['periodSeconds']).to eq 30
      expect(spec['livenessProbe']['timeoutSeconds']).to eq 5
      expect(spec['livenessProbe']['failureThreshold']).to eq 3
      expect(spec['readinessProbe']).to be_nil
    end

    it 'does not affect the web deployment probes' do
      spec = template.find_container('Deployment/optest-openproject-web', 'openproject')
      expect(spec['livenessProbe']['initialDelaySeconds']).to eq 20
      expect(spec['livenessProbe']['periodSeconds']).to eq 15
    end
  end
end
