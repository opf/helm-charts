# frozen_string_literal: true
require 'spec_helper'

describe 'tolerations' do
  let(:template) { HelmTemplate.new(default_values) }

  let(:definitions) {
    {
      /optest-openproject-seeder/ => 'seeder'
    }
  }

  context 'when setting tolerations' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        tolerations:
        - key: "key1"
          operator: "Equal"
          value: "value1"
          effect: "NoSchedule"
      YAML
      )
    end

    it 'adds that secret ref to relevant deployments', :aggregate_failures do
      definitions.each do |item, _|
        spec = template.template_spec(item)
        expect(spec['tolerations']).to be_a(Array)
        expect(spec['tolerations'].first['key']).to eq 'key1'
      end
    end
  end

  context 'when setting no tolerations' do
    let(:default_values) do
      {}
    end

    it 'adds the default secrets', :aggregate_failures do
      definitions.each do |item, _|
        spec = template.template_spec(item)
        expect(spec['tolerations']).to be_nil
      end
    end
  end
end
