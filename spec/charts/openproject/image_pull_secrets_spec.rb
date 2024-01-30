# frozen_string_literal: true
require 'spec_helper'

describe 'imagePullSecrets configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  let(:definitions) {
    %w[Deployment/optest-openproject-web Deployment/optest-openproject-worker-default]
  }

  context 'when setting global imagePullSecrets' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        global:
          imagePullSecrets:
            - mysecret
      YAML
      )
    end

    it 'Populates annotations for all deployments', :aggregate_failures do
      definitions.each do |name|
        expect(template.template_spec(name)['imagePullSecrets']).to eq([{ 'name' => 'mysecret' }])
      end
    end
  end

  context 'when setting no imagePullSecrets' do
    let(:default_values) do
      {}
    end

    it 'Populates annotations for all deployments', :aggregate_failures do
      definitions.each do |name|
        expect(template.template_spec(name)['imagePullSecrets']).to be_nil
      end
    end
  end
end
