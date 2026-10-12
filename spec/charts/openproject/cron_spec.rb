# frozen_string_literal: true
require 'spec_helper'

describe 'oidc configuration' do
  let(:default_values) { {} }
  let(:template) { HelmTemplate.new(default_values) }

  let(:cron_definition) do
    {
      'Deployment/optest-openproject-cron' => 'cron'
    }
  end

  let(:cron_secret_name) { 'optest-openproject-cron-environment' }

  let(:general_definitions) do
    {
      'Deployment/optest-openproject-web' => 'openproject',
      'Deployment/optest-openproject-worker-default' => 'openproject',
      /optest-openproject-seeder/ => 'seeder'
    }
  end

  let(:replicas) do
    template.dig 'Deployment/optest-openproject-cron', 'spec', 'replicas'
  end

  it 'adds a secret ref to the cron container' do
    ref = template.secret_ref cron_definition.keys.first, cron_definition.values.first, cron_secret_name

    expect(Hash(ref).dig('secretRef', 'name')).to eq cron_secret_name
  end

  it 'does not add a secret ref to the other containers' do
    general_definitions.each do |item, container|
      expect(template.secret_ref(item, container, cron_secret_name)).to be_nil
    end
  end

  context 'with cron.enabled=false (default)' do
    it 'does not schedule a cron container', :aggregate_failures do
      expect(replicas).to eq 0
    end
  end

  context 'with cron.enabled=true' do
    let(:default_values) do
      HelmTemplate.with_defaults('
        cron:
          enabled: true
      ')
    end

    it 'does schedule a cron container', :aggregate_failures do
      expect(replicas).to eq 1
    end
  end

  describe 'cron environment secret' do
    let(:cron_secret) do
      template.dig('Secret/optest-openproject-cron-environment', 'stringData')
    end

    let(:expected_keys) do
      %w[IMAP_HOST IMAP_PORT IMAP_USERNAME IMAP_PASSWORD]
    end

    context 'without an existing secret for the credentials configured' do
      let(:default_values) do
        HelmTemplate.with_defaults('
          cron:
            enabled: true
        ')
      end

      it 'contains the correct env variables', :aggregate_failures do
        expect(cron_secret.keys).to contain_exactly(*expected_keys)
      end
    end

    context 'with an existing secret for the credentials configured' do
      let(:default_values) do
        HelmTemplate.with_defaults('
          cron:
            enabled: true
            existingSecret: imap-credentials
        ')
      end

      it 'contains the correct env variables', :aggregate_failures do
        expect(cron_secret.keys).to contain_exactly(*expected_keys)
      end
    end
  end

  describe 'attachments volume' do
    let(:claim_name) do
      volumes = template.dig('Deployment/optest-openproject-cron', 'spec', 'template', 'spec', 'volumes')
      volumes.find { |v| v['name'] == 'data' }.dig('persistentVolumeClaim', 'claimName')
    end

    context 'without persistence.existingClaim' do
      let(:default_values) do
        HelmTemplate.with_defaults('
          cron:
            enabled: true
        ')
      end

      it 'mounts the chart-managed PVC' do
        expect(claim_name).to eq 'optest-openproject'
      end
    end

    context 'with persistence.existingClaim' do
      let(:default_values) do
        HelmTemplate.with_defaults('
          cron:
            enabled: true
          persistence:
            existingClaim: my-claim
        ')
      end

      it 'mounts the existing claim' do
        expect(claim_name).to eq 'my-claim'
      end
    end
  end

  describe 'probes' do
    let(:cron) { 'Deployment/optest-openproject-cron' }

    context 'with default configuration' do
      it 'defines liveness and readiness probes', :aggregate_failures do
        spec = template.find_container(cron, 'cron')
        %w[livenessProbe readinessProbe].each do |probe|
          expect(spec[probe]['exec']['command']).to eq ['bash', '-c', 'kill -0 1']
          expect(spec[probe]['timeoutSeconds']).to eq 5
        end
        expect(spec['livenessProbe']['periodSeconds']).to eq 15
        expect(spec['readinessProbe']['periodSeconds']).to eq 10
      end
    end

    context 'when disabling cron probes' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          cron:
            probes:
              enabled: false
        YAML
        )
      end

      it 'does not define probes', :aggregate_failures do
        spec = template.find_container(cron, 'cron')
        expect(spec['livenessProbe']).to be_nil
        expect(spec['readinessProbe']).to be_nil
      end
    end

    context 'when overriding probe settings for cron' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          cron:
            probes:
              liveness:
                initialDelaySeconds: 0
                failureThreshold: 5
              readiness:
                enabled: false
        YAML
        )
      end

      it 'merges the overrides over the global settings', :aggregate_failures do
        spec = template.find_container(cron, 'cron')
        expect(spec['livenessProbe']['initialDelaySeconds']).to eq 0
        expect(spec['livenessProbe']['failureThreshold']).to eq 5
        expect(spec['livenessProbe']['periodSeconds']).to eq 15
        expect(spec['readinessProbe']).to be_nil
      end
    end
  end
end
