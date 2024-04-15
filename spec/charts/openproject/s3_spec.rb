# frozen_string_literal: true
require 'spec_helper'

describe 's3 configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  subject { template.dig('Secret/optest-openproject-s3', 'stringData') }

  context 'when setting s3.port' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
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
end
