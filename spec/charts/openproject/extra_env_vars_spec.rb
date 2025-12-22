# frozen_string_literal: true
require 'spec_helper'

describe 'extraEnvVars configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when setting extraEnvVars' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        extraEnvVars:
          - name: CUSTOM_VAR_1
            value: "custom-value-1"
          - name: CUSTOM_VAR_2
            value: "custom-value-2"
          - name: CUSTOM_VAR_FROM_SECRET
            valueFrom:
              secretKeyRef:
                name: my-secret
                key: my-key
      YAML
      )
    end

    it 'adds extraEnvVars to web deployment container', :aggregate_failures do
      env = template.env('Deployment/optest-openproject-web', 'openproject')
      expect(env).not_to be_nil

      custom_var_1 = env.find { |e| e['name'] == 'CUSTOM_VAR_1' }
      expect(custom_var_1).not_to be_nil
      expect(custom_var_1['value']).to eq('custom-value-1')

      custom_var_2 = env.find { |e| e['name'] == 'CUSTOM_VAR_2' }
      expect(custom_var_2).not_to be_nil
      expect(custom_var_2['value']).to eq('custom-value-2')

      custom_var_from_secret = env.find { |e| e['name'] == 'CUSTOM_VAR_FROM_SECRET' }
      expect(custom_var_from_secret).not_to be_nil
      expect(custom_var_from_secret['valueFrom']['secretKeyRef']['name']).to eq('my-secret')
      expect(custom_var_from_secret['valueFrom']['secretKeyRef']['key']).to eq('my-key')
    end

    it 'adds extraEnvVars to worker deployment container', :aggregate_failures do
      env = template.env('Deployment/optest-openproject-worker-default', 'openproject')
      expect(env).not_to be_nil

      custom_var_1 = env.find { |e| e['name'] == 'CUSTOM_VAR_1' }
      expect(custom_var_1).not_to be_nil
      expect(custom_var_1['value']).to eq('custom-value-1')

      custom_var_2 = env.find { |e| e['name'] == 'CUSTOM_VAR_2' }
      expect(custom_var_2).not_to be_nil
      expect(custom_var_2['value']).to eq('custom-value-2')

      custom_var_from_secret = env.find { |e| e['name'] == 'CUSTOM_VAR_FROM_SECRET' }
      expect(custom_var_from_secret).not_to be_nil
      expect(custom_var_from_secret['valueFrom']['secretKeyRef']['name']).to eq('my-secret')
      expect(custom_var_from_secret['valueFrom']['secretKeyRef']['key']).to eq('my-key')
    end

    it 'adds extraEnvVars to seeder job container', :aggregate_failures do
      seeder_key = template.keys.find { |k| k.match?(/optest-openproject-seeder/) }
      expect(seeder_key).not_to be_nil

      env = template.env(seeder_key, 'seeder')
      expect(env).not_to be_nil

      custom_var_1 = env.find { |e| e['name'] == 'CUSTOM_VAR_1' }
      expect(custom_var_1).not_to be_nil
      expect(custom_var_1['value']).to eq('custom-value-1')

      custom_var_2 = env.find { |e| e['name'] == 'CUSTOM_VAR_2' }
      expect(custom_var_2).not_to be_nil
      expect(custom_var_2['value']).to eq('custom-value-2')
    end

    context 'when cron is enabled' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          cron:
            enabled: true
          extraEnvVars:
            - name: CUSTOM_VAR_1
              value: "custom-value-1"
        YAML
        )
      end

      it 'adds extraEnvVars to cron deployment container', :aggregate_failures do
        env = template.env('Deployment/optest-openproject-cron', 'cron')
        expect(env).not_to be_nil

        custom_var_1 = env.find { |e| e['name'] == 'CUSTOM_VAR_1' }
        expect(custom_var_1).not_to be_nil
        expect(custom_var_1['value']).to eq('custom-value-1')
      end
    end
  end

  context 'when extraEnvVars is empty' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        extraEnvVars: []
      YAML
      )
    end

    it 'does not add any extraEnvVars to web deployment container', :aggregate_failures do
      env = template.env('Deployment/optest-openproject-web', 'openproject')
      expect(env).not_to be_nil

      # Should still have other env vars like OPENPROJECT_DB_PASSWORD
      db_password = env.find { |e| e['name'] == 'OPENPROJECT_DB_PASSWORD' }
      expect(db_password).not_to be_nil

      # But no custom vars
      custom_var = env.find { |e| e['name'] == 'CUSTOM_VAR_1' }
      expect(custom_var).to be_nil
    end
  end

  context 'when extraEnvVars is not set' do
    let(:default_values) do
      HelmTemplate.with_defaults({})
    end

    it 'does not add any extraEnvVars to web deployment container', :aggregate_failures do
      binding.irb
      env = template.env('Deployment/optest-openproject-web', 'openproject')
      expect(env).not_to be_nil

      # Should still have other env vars like OPENPROJECT_DB_PASSWORD
      db_password = env.find { |e| e['name'] == 'OPENPROJECT_DB_PASSWORD' }
      expect(db_password).not_to be_nil

      # But no custom vars
      custom_var = env.find { |e| e['name'] == 'CUSTOM_VAR_1' }
      expect(custom_var).to be_nil
    end
  end
end
