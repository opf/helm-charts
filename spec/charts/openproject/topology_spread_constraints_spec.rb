# frozen_string_literal: true
require 'spec_helper'

describe 'topologySpreadConstraints configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when setting global topologySpreadConstraints only' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        topologySpreadConstraints:
          - maxSkew: 1
            topologyKey: kubernetes.io/hostname
            whenUnsatisfiable: DoNotSchedule
          - maxSkew: 2
            topologyKey: topology.kubernetes.io/zone
            whenUnsatisfiable: ScheduleAnyway
      YAML
      )
    end

    it 'applies global topologySpreadConstraints to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['topologySpreadConstraints'].length).to eq(2)

      first_constraint = web_spec['topologySpreadConstraints'][0]
      expect(first_constraint['maxSkew']).to eq(1)
      expect(first_constraint['topologyKey']).to eq('kubernetes.io/hostname')
      expect(first_constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
      expect(first_constraint['labelSelector']).to be_nil

      second_constraint = web_spec['topologySpreadConstraints'][1]
      expect(second_constraint['maxSkew']).to eq(2)
      expect(second_constraint['topologyKey']).to eq('topology.kubernetes.io/zone')
      expect(second_constraint['whenUnsatisfiable']).to eq('ScheduleAnyway')
    end

    it 'applies global topologySpreadConstraints to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['topologySpreadConstraints'].length).to eq(2)

      first_constraint = worker_spec['topologySpreadConstraints'][0]
      expect(first_constraint['maxSkew']).to eq(1)
      expect(first_constraint['topologyKey']).to eq('kubernetes.io/hostname')
      expect(first_constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
    end
  end

  context 'when setting web-specific topologySpreadConstraints' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        topologySpreadConstraints:
          - maxSkew: 1
            topologyKey: kubernetes.io/hostname
            whenUnsatisfiable: DoNotSchedule
        web:
          topologySpreadConstraints:
            - maxSkew: 2
              topologyKey: topology.kubernetes.io/zone
              whenUnsatisfiable: ScheduleAnyway
              labelSelector:
                matchLabels:
                  openproject/process: web
            - maxSkew: 1
              topologyKey: node.kubernetes.io/instance-type
              whenUnsatisfiable: DoNotSchedule
      YAML
      )
    end

    it 'applies web-specific topologySpreadConstraints to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['topologySpreadConstraints'].length).to eq(2)

      first_constraint = web_spec['topologySpreadConstraints'][0]
      expect(first_constraint['maxSkew']).to eq(2)
      expect(first_constraint['topologyKey']).to eq('topology.kubernetes.io/zone')
      expect(first_constraint['whenUnsatisfiable']).to eq('ScheduleAnyway')
      expect(first_constraint['labelSelector']['matchLabels']['openproject/process']).to eq('web')

      second_constraint = web_spec['topologySpreadConstraints'][1]
      expect(second_constraint['maxSkew']).to eq(1)
      expect(second_constraint['topologyKey']).to eq('node.kubernetes.io/instance-type')
      expect(second_constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
    end

    it 'applies global topologySpreadConstraints to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['topologySpreadConstraints'].length).to eq(1)

      constraint = worker_spec['topologySpreadConstraints'][0]
      expect(constraint['maxSkew']).to eq(1)
      expect(constraint['topologyKey']).to eq('kubernetes.io/hostname')
      expect(constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
    end
  end

  context 'when setting worker-specific topologySpreadConstraints' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        topologySpreadConstraints:
          - maxSkew: 1
            topologyKey: kubernetes.io/hostname
            whenUnsatisfiable: DoNotSchedule
        worker:
          topologySpreadConstraints:
            - maxSkew: 3
              topologyKey: topology.kubernetes.io/zone
              whenUnsatisfiable: ScheduleAnyway
              labelSelector:
                matchLabels:
                  openproject/process: worker-default
            - maxSkew: 1
              topologyKey: node.kubernetes.io/instance-type
              whenUnsatisfiable: DoNotSchedule
      YAML
      )
    end

    it 'applies global topologySpreadConstraints to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['topologySpreadConstraints'].length).to eq(1)

      constraint = web_spec['topologySpreadConstraints'][0]
      expect(constraint['maxSkew']).to eq(1)
      expect(constraint['topologyKey']).to eq('kubernetes.io/hostname')
      expect(constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
    end

    it 'applies worker-specific topologySpreadConstraints to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['topologySpreadConstraints'].length).to eq(2)

      first_constraint = worker_spec['topologySpreadConstraints'][0]
      expect(first_constraint['maxSkew']).to eq(3)
      expect(first_constraint['topologyKey']).to eq('topology.kubernetes.io/zone')
      expect(first_constraint['whenUnsatisfiable']).to eq('ScheduleAnyway')
      expect(first_constraint['labelSelector']['matchLabels']['openproject/process']).to eq('worker-default')

      second_constraint = worker_spec['topologySpreadConstraints'][1]
      expect(second_constraint['maxSkew']).to eq(1)
      expect(second_constraint['topologyKey']).to eq('node.kubernetes.io/instance-type')
      expect(second_constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
    end
  end

  context 'when setting both web and worker specific topologySpreadConstraints' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        topologySpreadConstraints:
          - maxSkew: 1
            topologyKey: kubernetes.io/hostname
            whenUnsatisfiable: DoNotSchedule
        web:
          topologySpreadConstraints:
            - maxSkew: 2
              topologyKey: topology.kubernetes.io/zone
              whenUnsatisfiable: ScheduleAnyway
              labelSelector:
                matchLabels:
                  openproject/process: web
        worker:
          topologySpreadConstraints:
            - maxSkew: 3
              topologyKey: topology.kubernetes.io/zone
              whenUnsatisfiable: ScheduleAnyway
              labelSelector:
                matchLabels:
                  openproject/process: worker-default
      YAML
      )
    end

    it 'applies web-specific topologySpreadConstraints to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['topologySpreadConstraints'].length).to eq(1)

      constraint = web_spec['topologySpreadConstraints'][0]
      expect(constraint['maxSkew']).to eq(2)
      expect(constraint['topologyKey']).to eq('topology.kubernetes.io/zone')
      expect(constraint['whenUnsatisfiable']).to eq('ScheduleAnyway')
      expect(constraint['labelSelector']['matchLabels']['openproject/process']).to eq('web')
    end

    it 'applies worker-specific topologySpreadConstraints to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['topologySpreadConstraints'].length).to eq(1)

      constraint = worker_spec['topologySpreadConstraints'][0]
      expect(constraint['maxSkew']).to eq(3)
      expect(constraint['topologyKey']).to eq('topology.kubernetes.io/zone')
      expect(constraint['whenUnsatisfiable']).to eq('ScheduleAnyway')
      expect(constraint['labelSelector']['matchLabels']['openproject/process']).to eq('worker-default')
    end
  end

  context 'when setting empty topologySpreadConstraints' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        topologySpreadConstraints: []
        web:
          topologySpreadConstraints: []
        worker:
          topologySpreadConstraints: []
      YAML
      )
    end

    it 'does not set topologySpreadConstraints on web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['topologySpreadConstraints']).to be_nil
    end

    it 'does not set topologySpreadConstraints on worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['topologySpreadConstraints']).to be_nil
    end
  end

  context 'when setting no topologySpreadConstraints configuration' do
    let(:default_values) do
      {}
    end

    it 'does not set topologySpreadConstraints on any deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')

      expect(web_spec['topologySpreadConstraints']).to be_nil
      expect(worker_spec['topologySpreadConstraints']).to be_nil
    end
  end

  context 'when setting partial topologySpreadConstraints configurations' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        topologySpreadConstraints:
          - maxSkew: 1
            topologyKey: kubernetes.io/hostname
            whenUnsatisfiable: DoNotSchedule
        web:
          topologySpreadConstraints:
            - maxSkew: 2
              topologyKey: topology.kubernetes.io/zone
              whenUnsatisfiable: ScheduleAnyway
              labelSelector:
                matchLabels:
                  openproject/process: web
        # worker topologySpreadConstraints not set
      YAML
      )
    end

    it 'applies web-specific topologySpreadConstraints to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['topologySpreadConstraints'].length).to eq(1)

      constraint = web_spec['topologySpreadConstraints'][0]
      expect(constraint['maxSkew']).to eq(2)
      expect(constraint['topologyKey']).to eq('topology.kubernetes.io/zone')
      expect(constraint['whenUnsatisfiable']).to eq('ScheduleAnyway')
    end

    it 'applies global topologySpreadConstraints to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['topologySpreadConstraints'].length).to eq(1)

      constraint = worker_spec['topologySpreadConstraints'][0]
      expect(constraint['maxSkew']).to eq(1)
      expect(constraint['topologyKey']).to eq('kubernetes.io/hostname')
      expect(constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
    end
  end

  context 'when setting topologySpreadConstraints with Karpenter-specific configuration' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        topologySpreadConstraints:
          - maxSkew: 1
            topologyKey: karpenter.sh/capacity-type
            whenUnsatisfiable: DoNotSchedule
          - maxSkew: 2
            topologyKey: topology.kubernetes.io/zone
            whenUnsatisfiable: ScheduleAnyway
        web:
          topologySpreadConstraints:
            - maxSkew: 1
              topologyKey: karpenter.sh/capacity-type
              whenUnsatisfiable: DoNotSchedule
              labelSelector:
                matchLabels:
                  openproject/process: web
            - maxSkew: 1
              topologyKey: node.kubernetes.io/instance-type
              whenUnsatisfiable: DoNotSchedule
      YAML
      )
    end

    it 'applies Karpenter-specific topologySpreadConstraints to web deployment', :aggregate_failures do
      web_spec = template.template_spec('Deployment/optest-openproject-web')
      expect(web_spec['topologySpreadConstraints'].length).to eq(2)

      first_constraint = web_spec['topologySpreadConstraints'][0]
      expect(first_constraint['maxSkew']).to eq(1)
      expect(first_constraint['topologyKey']).to eq('karpenter.sh/capacity-type')
      expect(first_constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
      expect(first_constraint['labelSelector']['matchLabels']['openproject/process']).to eq('web')

      second_constraint = web_spec['topologySpreadConstraints'][1]
      expect(second_constraint['maxSkew']).to eq(1)
      expect(second_constraint['topologyKey']).to eq('node.kubernetes.io/instance-type')
      expect(second_constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
    end

    it 'applies global topologySpreadConstraints to worker deployment', :aggregate_failures do
      worker_spec = template.template_spec('Deployment/optest-openproject-worker-default')
      expect(worker_spec['topologySpreadConstraints'].length).to eq(2)

      first_constraint = worker_spec['topologySpreadConstraints'][0]
      expect(first_constraint['maxSkew']).to eq(1)
      expect(first_constraint['topologyKey']).to eq('karpenter.sh/capacity-type')
      expect(first_constraint['whenUnsatisfiable']).to eq('DoNotSchedule')
    end
  end
end
