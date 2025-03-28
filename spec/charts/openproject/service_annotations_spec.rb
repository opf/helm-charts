# frozen_string_literal: true
require 'spec_helper'

describe 'service annotations' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when setting annotations' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        service:
          annotations:  
            prometheus.io/host: 'foobar.example'
            prometheus.io/port: '8080'
      YAML
      )
    end

    it 'adds the annotations', :aggregate_failures do
      annotations = template.dig("Service/optest-openproject", "metadata", "annotations")

      expect(annotations["prometheus.io/host"]).to eq 'foobar.example'
      expect(annotations["prometheus.io/port"]).to eq '8080'
    end
  end

  context 'when setting no tolerations' do
    let(:default_values) do
      {}
    end

    it 'adds the default secrets', :aggregate_failures do
      annotations = template.dig("Service/optest-openproject", "metadata", "annotations")
      expect(annotations).to be_nil
    end
  end
end
