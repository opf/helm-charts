# frozen_string_literal: true
require 'spec_helper'

describe 'imagePullSecrets configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when setting custom workers' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        workers:
          default:
            queues: ""
            replicaCount: 1
            strategy:
              type: "Recreate"
          multitenancy:
            queues: "multitenancy"
            replicaCount: 1
            strategy:
              type: "Recreate"
          bim:
            queues: "bim,ifc_conversion"
            replicaCount: 0
            strategy:
              type: "Recreate"
              YAML
      )
    end

    it 'Creates the different worker deployments', :aggregate_failures do
      expect(template.keys).to include 'Deployment/optest-openproject-worker-default'
      expect(template.dig('Deployment/optest-openproject-worker-default', 'spec', 'replicas'))
        .to eq(1)
      expect(template.env('Deployment/optest-openproject-worker-default', 'openproject', 'OPENPROJECT_GOOD_JOB_QUEUES'))
        .to be_nil

      expect(template.keys).to include 'Deployment/optest-openproject-worker-multitenancy'
      expect(template.dig('Deployment/optest-openproject-worker-multitenancy', 'spec', 'replicas'))
        .to eq(1)
      expect(template.env_named('Deployment/optest-openproject-worker-multitenancy', 'openproject', 'OPENPROJECT_GOOD_JOB_QUEUES')['value'])
        .to eq('multitenancy')

      expect(template.keys).to include 'Deployment/optest-openproject-worker-bim'
      expect(template.dig('Deployment/optest-openproject-worker-bim', 'spec', 'replicas'))
        .to eq(0)
      expect(template.env_named('Deployment/optest-openproject-worker-bim', 'openproject', 'OPENPROJECT_GOOD_JOB_QUEUES')['value'])
        .to eq('bim,ifc_conversion')
    end
  end

  context 'when setting no workers' do
    let(:default_values) do
      {}
    end

    it 'Creates the default worker', :aggregate_failures do
      expect(template.keys).to include 'Deployment/optest-openproject-worker-default'
    end
  end
end
