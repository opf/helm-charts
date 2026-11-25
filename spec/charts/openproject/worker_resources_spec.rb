# frozen_string_literal: true
require 'spec_helper'

describe 'worker resources configuration' do
  let(:template) { HelmTemplate.new(default_values) }
  let(:worker) { 'Deployment/optest-openproject-worker-default' }

  context 'when changing the top-level resources' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        resources:
          limits:
            cpu: "2"
        workers:
          bim:
            queues: "bim"
            resources:
              limits:
                cpu: "1"
      YAML
      )
    end

    it 'applies them to every worker unless overridden', :aggregate_failures do
      spec = template.find_container(worker, 'openproject')
      expect(spec['resources']['limits']['cpu']).to eq '2'

      bim = template.find_container('Deployment/optest-openproject-worker-bim', 'openproject')
      expect(bim['resources']).to eq('limits' => { 'cpu' => '1' })
    end
  end
end
