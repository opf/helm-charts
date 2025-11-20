# frozen_string_literal: true
require 'spec_helper'

describe 'configuring hocuspocus' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when hocuspocus is disabled (default) while the global ingress is enabled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: true
        YAML
      )
    end

    it 'does not add the hocuspocus ingress', :aggregate_failures do
      paths = template.dig('Ingress/optest-openproject', 'spec', 'rules').first['http']['paths']

      expect(paths.size).to eq 1
      expect(paths.first['path']).to eq '/'
    end
  end

  context 'when hocuspocus is enabled while the global ingress is enabled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: true
          hocuspocus:
            enabled: true
        YAML
      )
    end

    it 'adds the hocuspocus ingress', :aggregate_failures do
      paths = template.dig('Ingress/optest-openproject', 'spec', 'rules').first['http']['paths']

      expect(paths.size).to eq 2
      expect(paths.first['path']).to eq '/hocuspocus'
      expect(paths.last['path']).to eq '/'
    end
  end

  context 'when the global ingress is disabled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: false
        YAML
      )
    end

    it 'does not define an ingress' do
      ingress = template['Ingress/optest-openproject']

      expect(ingress).to be_nil
    end
  end

  context 'auth secrets' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          hocuspocus:
            enabled: true
        YAML
      )
    end

    it 'sets the SECRET environment variable' do
      deployment = template.dig('Deployment/optest-openproject-hocuspocus')
      env = deployment.dig('spec', 'template', 'spec', 'containers').first['env']
      secret_env = env.find { |e| e['name'] == 'SECRET' }

      expect(secret_env).not_to be_nil
      expect(secret_env['valueFrom']['secretKeyRef']['key']).to eq 'secret'
    end
  end

  context 'when allowedOpenProjectDomains is configured' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          hocuspocus:
            enabled: true
            allowedOpenProjectDomains:
              - example.org
              - sometest.com
        YAML
      )
    end

    it 'sets the ALLOWED_DOMAINS environment variable with comma-separated domains' do
      deployment = template.dig('Deployment/optest-openproject-hocuspocus')
      env = deployment.dig('spec', 'template', 'spec', 'containers').first['env']
      allowed_domains_env = env.find { |e| e['name'] == 'ALLOWED_DOMAINS' }

      expect(allowed_domains_env).not_to be_nil
      expect(allowed_domains_env['value']).to eq 'example.org,sometest.com'
    end
  end

  context 'when allowedOpenProjectDomains uses default values' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          hocuspocus:
            enabled: true
        YAML
      )
    end

    it 'sets the ALLOWED_DOMAINS environment variable with default domain' do
      deployment = template.dig('Deployment/optest-openproject-hocuspocus')
      env = deployment.dig('spec', 'template', 'spec', 'containers').first['env']
      allowed_domains_env = env.find { |e| e['name'] == 'ALLOWED_DOMAINS' }

      expect(allowed_domains_env).not_to be_nil
      expect(allowed_domains_env['value']).to eq 'openproject.example.com'
    end
  end
end
