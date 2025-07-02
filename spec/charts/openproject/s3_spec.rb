# frozen_string_literal: true

require 'spec_helper'

describe 's3 configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  subject { template.dig('Secret/optest-openproject-s3', 'stringData') }

  context 'when setting s3.port' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          s3:
            enabled: true
            host: bla.example.com
            port: 9000
        YAML
      )
    end

    it 'adds a respective ENV', :aggregate_failures do
      expect(subject)
        .to include(
              "OPENPROJECT_ATTACHMENTS__STORAGE" => "fog",
              "OPENPROJECT_FOG_CREDENTIALS_PROVIDER" => "AWS",
              "OPENPROJECT_FOG_CREDENTIALS_HOST" => "bla.example.com",
              "OPENPROJECT_FOG_CREDENTIALS_PORT" => "9000",
              "OPENPROJECT_FOG_CREDENTIALS_PATH__STYLE" => "false",
              "OPENPROJECT_FOG_CREDENTIALS_AWS__SIGNATURE__VERSION" => "4",
              "OPENPROJECT_FOG_CREDENTIALS_USE__IAM__PROFILE" => "false",
              "OPENPROJECT_DIRECT__UPLOADS" => "true"
            )
    end
  end

  context 'when setting no s3 config' do
    let(:default_values) do
      {}
    end

    it 'the s3 config is empty', :aggregate_failures do
      expect(subject).to be_nil
    end
  end

  context 'when enabled, but no port set' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        s3:
          enabled: true
          host: bla.example.com
      YAML
      )
    end

    it 'the s3 config is empty', :aggregate_failures do
      expect(subject).to have_key('OPENPROJECT_FOG_CREDENTIALS_HOST')
      expect(subject).not_to have_key('OPENPROJECT_FOG_CREDENTIALS_PORT')
    end
  end

  context 'when enabled with access credentials' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        s3:
          enabled: true
          host: bla.example.com
          auth:
            accessKeyId: test-access-key
            secretAccessKey: test-secret-key
      YAML
      )
    end

    it 'includes access credentials in the secret', :aggregate_failures do
      expect(subject).to include(
        "OPENPROJECT_FOG_CREDENTIALS_AWS__ACCESS__KEY__ID" => "test-access-key",
        "OPENPROJECT_FOG_CREDENTIALS_AWS__SECRET__ACCESS__KEY" => "test-secret-key"
      )
    end
  end

  context 'when using an existing secret' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        s3:
          enabled: true
          host: bla.example.com
          auth:
            existingSecret: my-existing-s3-secret
      YAML
      )
    end

    it 'does not include access credentials in the generated secret', :aggregate_failures do
      expect(subject).not_to have_key('OPENPROJECT_FOG_CREDENTIALS_AWS__ACCESS__KEY__ID')
      expect(subject).not_to have_key('OPENPROJECT_FOG_CREDENTIALS_AWS__SECRET__ACCESS__KEY')
    end

    it 'still includes other s3 configuration', :aggregate_failures do
      expect(subject).to include(
        "OPENPROJECT_ATTACHMENTS__STORAGE" => "fog",
        "OPENPROJECT_FOG_CREDENTIALS_PROVIDER" => "AWS",
        "OPENPROJECT_FOG_CREDENTIALS_HOST" => "bla.example.com"
      )
    end
  end
end

describe 's3 envFrom configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when s3 is enabled without existing secret' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        s3:
          enabled: true
          host: bla.example.com
      YAML
      )
    end

    it 'includes only the generated s3 secret in envFrom', :aggregate_failures do
      web_deployment = template.dig('Deployment/optest-openproject-web')
      env_from = web_deployment.dig('spec', 'template', 'spec', 'containers', 0, 'envFrom')

      s3_secrets = env_from.select { |item| item.dig('secretRef', 'name')&.include?('s3') }
      expect(s3_secrets).to contain_exactly(
        { 'secretRef' => { 'name' => 'optest-openproject-s3' } }
      )
    end
  end

  context 'when s3 is enabled with existing secret' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        s3:
          enabled: true
          host: bla.example.com
          auth:
            existingSecret: my-existing-s3-secret
      YAML
      )
    end

    it 'includes both generated and existing secrets in envFrom', :aggregate_failures do
      web_deployment = template.dig('Deployment/optest-openproject-web')
      env_from = web_deployment.dig('spec', 'template', 'spec', 'containers', 0, 'envFrom')

      s3_secrets = env_from.select { |item| item.dig('secretRef', 'name')&.include?('s3') }
      expect(s3_secrets).to contain_exactly(
        { 'secretRef' => { 'name' => 'optest-openproject-s3' } },
        { 'secretRef' => { 'name' => 'my-existing-s3-secret' } }
      )
    end
  end
end
