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
end
