# frozen_string_literal: true
require 'spec_helper'

describe 'nodeSelector configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when setting global nodeSelector only' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector:
          node-type: general
          workload: default
      YAML
      )
    end

    it 'applies global nodeSelector to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['nodeSelector']).to include('node-type' => 'general')
      expect(web_spec['nodeSelector']).to include('workload' => 'default')
    end

    it 'applies global nodeSelector to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['nodeSelector']).to include('node-type' => 'general')
      expect(worker_spec['nodeSelector']).to include('workload' => 'default')
    end

    it 'applies global nodeSelector to cron deployment', :aggregate_failures do
      cron_spec = template.template_spec('Deployment/optest-openproject-cron')
      expect(cron_spec['nodeSelector']).to include('node-type' => 'general')
      expect(cron_spec['nodeSelector']).to include('workload' => 'default')
    end
  end

  context 'when setting web-specific nodeSelector' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector:
          node-type: general
          workload: default
        web:
          nodeSelector:
            node-type: web
            workload: frontend
            zone: us-west-1a
      YAML
      )
    end

    it 'applies web-specific nodeSelector to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['nodeSelector']).to include('node-type' => 'web')
      expect(web_spec['nodeSelector']).to include('workload' => 'frontend')
      expect(web_spec['nodeSelector']).to include('zone' => 'us-west-1a')
      expect(web_spec['nodeSelector']).not_to include('node-type' => 'general')
    end

    it 'applies global nodeSelector to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['nodeSelector']).to include('node-type' => 'general')
      expect(worker_spec['nodeSelector']).to include('workload' => 'default')
      expect(worker_spec['nodeSelector']).not_to include('node-type' => 'web')
    end

    it 'applies global nodeSelector to cron deployment', :aggregate_failures do
      cron_spec = template.template_spec('Deployment/optest-openproject-cron')
      expect(cron_spec['nodeSelector']).to include('node-type' => 'general')
      expect(cron_spec['nodeSelector']).to include('workload' => 'default')
    end
  end

  context 'when setting worker-specific nodeSelector' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector:
          node-type: general
          workload: default
        worker:
          nodeSelector:
            node-type: worker
            workload: background
            zone: us-west-1b
      YAML
      )
    end

    it 'applies global nodeSelector to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['nodeSelector']).to include('node-type' => 'general')
      expect(web_spec['nodeSelector']).to include('workload' => 'default')
      expect(web_spec['nodeSelector']).not_to include('node-type' => 'worker')
    end

    it 'applies worker-specific nodeSelector to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['nodeSelector']).to include('node-type' => 'worker')
      expect(worker_spec['nodeSelector']).to include('workload' => 'background')
      expect(worker_spec['nodeSelector']).to include('zone' => 'us-west-1b')
      expect(worker_spec['nodeSelector']).not_to include('node-type' => 'general')
    end

    it 'applies global nodeSelector to cron deployment', :aggregate_failures do
      cron_spec = template.template_spec('Deployment/optest-openproject-cron')
      expect(cron_spec['nodeSelector']).to include('node-type' => 'general')
      expect(cron_spec['nodeSelector']).to include('workload' => 'default')
    end
  end

  context 'when setting both web and worker specific nodeSelectors' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector:
          node-type: general
          workload: default
        web:
          nodeSelector:
            node-type: web
            workload: frontend
            zone: us-west-1a
        worker:
          nodeSelector:
            node-type: worker
            workload: background
            zone: us-west-1b
      YAML
      )
    end

    it 'applies web-specific nodeSelector to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['nodeSelector']).to include('node-type' => 'web')
      expect(web_spec['nodeSelector']).to include('workload' => 'frontend')
      expect(web_spec['nodeSelector']).to include('zone' => 'us-west-1a')
      expect(web_spec['nodeSelector']).not_to include('node-type' => 'general')
      expect(web_spec['nodeSelector']).not_to include('node-type' => 'worker')
    end

    it 'applies worker-specific nodeSelector to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['nodeSelector']).to include('node-type' => 'worker')
      expect(worker_spec['nodeSelector']).to include('workload' => 'background')
      expect(worker_spec['nodeSelector']).to include('zone' => 'us-west-1b')
      expect(worker_spec['nodeSelector']).not_to include('node-type' => 'general')
      expect(worker_spec['nodeSelector']).not_to include('node-type' => 'web')
    end

    it 'applies global nodeSelector to cron deployment', :aggregate_failures do
      cron_spec = template.template_spec('Deployment/optest-openproject-cron')
      expect(cron_spec['nodeSelector']).to include('node-type' => 'general')
      expect(cron_spec['nodeSelector']).to include('workload' => 'default')
      expect(cron_spec['nodeSelector']).not_to include('node-type' => 'web')
      expect(cron_spec['nodeSelector']).not_to include('node-type' => 'worker')
    end
  end

  context 'when setting empty nodeSelectors' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector: {}
        web:
          nodeSelector: {}
        worker:
          nodeSelector: {}
      YAML
      )
    end

    it 'does not set nodeSelector on web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['nodeSelector']).to be_nil
    end

    it 'does not set nodeSelector on worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['nodeSelector']).to be_nil
    end

    it 'does not set nodeSelector on cron deployment', :aggregate_failures do
      cron_spec = template.template_spec('Deployment/optest-openproject-cron')
      expect(cron_spec['nodeSelector']).to be_nil
    end
  end

  context 'when setting no nodeSelector configuration' do
    let(:default_values) do
      {}
    end

    it 'does not set nodeSelector on any deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      cron_spec = template.template_spec('Deployment/optest-openproject-cron')

      expect(web_spec['nodeSelector']).to be_nil
      expect(worker_spec['nodeSelector']).to be_nil
      expect(cron_spec['nodeSelector']).to be_nil
    end
  end

  context 'when setting partial nodeSelector configurations' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector:
          node-type: general
        web:
          nodeSelector:
            node-type: web
        # worker nodeSelector not set
      YAML
      )
    end

    it 'applies web-specific nodeSelector to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['nodeSelector']).to include('node-type' => 'web')
      expect(web_spec['nodeSelector']).not_to include('node-type' => 'general')
    end

    it 'applies global nodeSelector to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['nodeSelector']).to include('node-type' => 'general')
      expect(worker_spec['nodeSelector']).not_to include('node-type' => 'web')
    end

    it 'applies global nodeSelector to cron deployment', :aggregate_failures do
      cron_spec = template.template_spec('Deployment/optest-openproject-cron')
      expect(cron_spec['nodeSelector']).to include('node-type' => 'general')
    end
  end
end
