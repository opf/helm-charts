# frozen_string_literal: true
require 'spec_helper'

describe 'host name configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  subject { template.dig('Secret/optest-openproject-core', 'stringData') }

  context 'when setting host' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        openproject:
          host: bla.example.com
      YAML
      )
    end

    it 'adds a respective ENV', :aggregate_failures do
      expect(subject)
        .to include("OPENPROJECT_HOST__NAME" => "bla.example.com")
    end
  end

  context 'when setting no host name but leaving ingress enabled' do
    let(:default_values) do
      HelmTemplate.with_defaults({})
    end

    it 'the host name is the default', :aggregate_failures do
      expect(subject)
        .to include("OPENPROJECT_HOST__NAME" => "openproject.example.com")
    end
  end

  context 'when setting no host name and disabling ingress' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        ingress:
          enabled: false
      YAML
      )
    end

    it 'the host is not output', :aggregate_failures do
      expect(subject.keys)
        .not_to include("OPENPROJECT_HOST__NAME")
    end
  end

  context 'when setting host name and disabling ingress' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        ingress:
          enabled: false
        openproject:
          host: foo.example.com
      YAML
      )
    end

    it 'the host is not output', :aggregate_failures do
      expect(subject)
        .to include("OPENPROJECT_HOST__NAME" => "foo.example.com")

    end
  end
end
