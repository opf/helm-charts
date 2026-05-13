# frozen_string_literal: true
require 'spec_helper'

describe 'configuring SECRET_KEY_BASE' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when no existingSecret is given' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          openproject:
            secretKeyBase:
              existingSecret: ""
        YAML
      )
    end

    it 'auto-generates a secret' do
      secret = template.dig('Secret/secret-key-base-auto-generated')

      expect(secret).not_to be_nil
      expect(secret.dig('stringData', 'secret-key-base')).not_to be_empty
    end

    it 'points SECRET_KEY_BASE to the auto-generated secret in the web deployment' do
      env = template.env_named('Deployment/optest-openproject-web', 'openproject', 'SECRET_KEY_BASE')

      expect(env).not_to be_nil
      expect(env.dig('valueFrom', 'secretKeyRef', 'name')).to eq 'secret-key-base-auto-generated'
      expect(env.dig('valueFrom', 'secretKeyRef', 'key')).to eq 'secret-key-base'
    end

    it 'points SECRET_KEY_BASE to the auto-generated secret in the worker deployment' do
      env = template.env_named('Deployment/optest-openproject-worker-default', 'openproject', 'SECRET_KEY_BASE')

      expect(env).not_to be_nil
      expect(env.dig('valueFrom', 'secretKeyRef', 'name')).to eq 'secret-key-base-auto-generated'
      expect(env.dig('valueFrom', 'secretKeyRef', 'key')).to eq 'secret-key-base'
    end
  end

  context 'when an existingSecret is given' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          openproject:
            secretKeyBase:
              existingSecret: my-secret-key-base
              secretKey: my-key
        YAML
      )
    end

    it 'does not auto-generate a secret' do
      secret = template.dig('Secret/secret-key-base-auto-generated')

      expect(secret).to be_nil
    end

    it 'points SECRET_KEY_BASE to the existing secret in the web deployment' do
      env = template.env_named('Deployment/optest-openproject-web', 'openproject', 'SECRET_KEY_BASE')

      expect(env).not_to be_nil
      expect(env.dig('valueFrom', 'secretKeyRef', 'name')).to eq 'my-secret-key-base'
      expect(env.dig('valueFrom', 'secretKeyRef', 'key')).to eq 'my-key'
    end

    it 'points SECRET_KEY_BASE to the existing secret in the worker deployment' do
      env = template.env_named('Deployment/optest-openproject-worker-default', 'openproject', 'SECRET_KEY_BASE')

      expect(env).not_to be_nil
      expect(env.dig('valueFrom', 'secretKeyRef', 'name')).to eq 'my-secret-key-base'
      expect(env.dig('valueFrom', 'secretKeyRef', 'key')).to eq 'my-key'
    end
  end

  context 'when SECRET_KEY_BASE is provided via environment values' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          environment:
            SECRET_KEY_BASE: manually-configured-secret-key-base
        YAML
      )
    end

    it 'does not auto-generate a secret' do
      secret = template.dig('Secret/secret-key-base-auto-generated')

      expect(secret).to be_nil
    end

    it 'adds SECRET_KEY_BASE to the environment secret' do
      secret = template.dig('Secret/optest-openproject-environment')

      expect(secret.dig('stringData', 'SECRET_KEY_BASE')).to eq 'manually-configured-secret-key-base'
    end

    it 'does not point SECRET_KEY_BASE to a secret in the web deployment' do
      env = template.env_named('Deployment/optest-openproject-web', 'openproject', 'SECRET_KEY_BASE')

      expect(env).to be_nil
    end

    it 'does not point SECRET_KEY_BASE to a secret in the worker deployment' do
      env = template.env_named('Deployment/optest-openproject-worker-default', 'openproject', 'SECRET_KEY_BASE')

      expect(env).to be_nil
    end
  end
end
