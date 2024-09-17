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
end
