# frozen_string_literal: true
require 'spec_helper'

describe 'worker probes configuration' do
  let(:template) { HelmTemplate.new(default_values) }
  let(:worker) { 'Deployment/optest-openproject-worker-default' }

  context 'when disabling probes' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        workers:
          default:
            queues: ""
            replicas: 1
            probes:
              enabled: false
              port: 7001
      YAML
      )
    end

    it 'does not define worker probes', :aggregate_failures do
      expect(template.keys).to include worker

      spec = template.find_container(worker, 'openproject')
      expect(spec['livenessProbe']).to be_nil
      expect(spec['readinessProbe']).to be_nil

      env = template.env_named(worker, 'openproject', 'GOOD_JOB_PROBE_PORT')
      expect(env).to be_nil
    end
  end

  context 'when setting custom port' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        workers:
          default:
            queues: ""
            replicas: 1
            probes:
              enabled: true
              port: 9999
      YAML
      )
    end

    it 'does define the probe', :aggregate_failures do
      expect(template.keys).to include worker
      spec = template.find_container(worker, 'openproject')
      expect(spec['livenessProbe']).to be_a(Hash)
      expect(spec['readinessProbe']).to be_a(Hash)
      expect(spec['readinessProbe']['httpGet']['port']).to eq 9999
      expect(spec['livenessProbe']['httpGet']['port']).to eq 9999

      env = template.env_named(worker, 'openproject', 'GOOD_JOB_PROBE_PORT')
      expect(env).to be_a(Hash)
      expect(env['value']).to eq '9999'
    end
  end

  context 'with default configuration' do
    let(:default_values) do
      {}
    end

    it 'uses the default probes', :aggregate_failures do
      expect(template.keys).to include worker
      spec = template.find_container(worker, 'openproject')
      expect(spec['livenessProbe']).to be_a(Hash)
      expect(spec['readinessProbe']).to be_a(Hash)
      expect(spec['readinessProbe']['httpGet']['port']).to eq 7001
      expect(spec['livenessProbe']['httpGet']['port']).to eq 7001

      env = template.env_named(worker, 'openproject', 'GOOD_JOB_PROBE_PORT')
      expect(env).to be_a(Hash)
      expect(env['value']).to eq '7001'
    end
  end

  context 'when overriding probe settings for a worker' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        probes:
          liveness:
            initialDelaySeconds: 20
        workers:
          default:
            probes:
              liveness:
                initialDelaySeconds: 0
                periodSeconds: 30
              readiness:
                enabled: false
      YAML
      )
    end

    it 'merges the worker overrides over the global settings', :aggregate_failures do
      spec = template.find_container(worker, 'openproject')
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
