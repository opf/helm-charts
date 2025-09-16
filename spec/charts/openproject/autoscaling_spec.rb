require_relative '../../spec_helper'

describe 'openproject KEDA autoscaling' do
  let(:default_values) do
    HelmTemplate.with_defaults({})
  end

  let(:keda_enabled_values) do
    HelmTemplate.with_defaults({
      'keda' => {
        'enabled' => true,
        'minReplicaCount' => 2,
        'maxReplicaCount' => 10,
        'pollingInterval' => 30,
        'cooldownPeriod' => 300,
        'triggers' => [
          {
            'type' => 'cpu',
            'metadata' => {
              'type' => 'Utilization',
              'value' => '70'
            }
          }
        ]
      }
    })
  end

  let(:prometheus_scaling_values) do
    HelmTemplate.with_defaults({
      'keda' => {
        'enabled' => true,
        'minReplicaCount' => 1,
        'maxReplicaCount' => 20,
        'triggers' => [
          {
            'type' => 'prometheus',
            'metadata' => {
              'serverAddress' => 'http://prometheus-server.monitoring.svc.cluster.local:80',
              'metricName' => 'openproject_requests_in_flight',
              'query' => 'avg(sum by (pod) (openproject_requests_in_flight{pod=~".*web.*"}))',
              'threshold' => '30'
            }
          },
          {
            'type' => 'prometheus',
            'metadata' => {
              'serverAddress' => 'http://prometheus-server.monitoring.svc.cluster.local:80',
              'metricName' => 'openproject_queue_depth', 
              'query' => 'sum(openproject_background_jobs_queue_size)',
              'threshold' => '50'
            }
          }
        ]
      }
    })
  end

  let(:advanced_keda_values) do
    HelmTemplate.with_defaults({
      'keda' => {
        'enabled' => true,
        'minReplicaCount' => 3,
        'maxReplicaCount' => 15,
        'fallback' => {
          'failureThreshold' => 3,
          'replicas' => 2
        },
        'advanced' => {
          'restoreToOriginalReplicaCount' => true,
          'horizontalPodAutoscalerConfig' => {
            'behavior' => {
              'scaleDown' => {
                'stabilizationWindowSeconds' => 300
              }
            }
          }
        },
        'triggers' => [
          {
            'type' => 'memory',
            'metadata' => {
              'type' => 'Utilization',
              'value' => '80'
            }
          }
        ]
      }
    })
  end

  context 'when KEDA is disabled' do
    it 'should not create ScaledObject resource' do
      t = HelmTemplate.new(default_values)
      expect(t.dig('ScaledObject/optest-openproject-web-scaler')).to be_nil
    end

    it 'should set replica count on web deployment' do
      t = HelmTemplate.new(default_values.merge({ 'replicaCount' => 3 }))
      expect(t.dig('Deployment/optest-openproject-web', 'spec', 'replicas')).to eq(3)
    end

    it 'should not add KEDA annotations to deployment' do
      t = HelmTemplate.new(default_values)
      deployment = t.dig('Deployment/optest-openproject-web')
      annotations = deployment&.dig('metadata', 'annotations')
      expect(annotations).to be_nil or not include('autoscaling.keda.sh/paused-replicas')
    end
  end

  context 'when KEDA is enabled' do
    it 'should create ScaledObject resource' do
      t = HelmTemplate.new(keda_enabled_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      expect(scaledobject).not_to be_nil
      expect(scaledobject['apiVersion']).to eq('keda.sh/v1alpha1')
      expect(scaledobject['kind']).to eq('ScaledObject')
    end

    it 'should configure ScaledObject target reference' do
      t = HelmTemplate.new(keda_enabled_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      target_ref = scaledobject['spec']['scaleTargetRef']
      expect(target_ref['apiVersion']).to eq('apps/v1')
      expect(target_ref['kind']).to eq('Deployment')
      expect(target_ref['name']).to eq('optest-openproject-web')
    end

    it 'should set min and max replica counts' do
      t = HelmTemplate.new(keda_enabled_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      expect(scaledobject['spec']['minReplicaCount']).to eq(2)
      expect(scaledobject['spec']['maxReplicaCount']).to eq(10)
    end

    it 'should configure polling and cooldown periods' do
      t = HelmTemplate.new(keda_enabled_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      expect(scaledobject['spec']['pollingInterval']).to eq(30)
      expect(scaledobject['spec']['cooldownPeriod']).to eq(300)
    end

    it 'should configure CPU trigger' do
      t = HelmTemplate.new(keda_enabled_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      triggers = scaledobject['spec']['triggers']
      expect(triggers).to be_an(Array)
      expect(triggers.length).to eq(1)

      cpu_trigger = triggers.first
      expect(cpu_trigger['type']).to eq('cpu')
      expect(cpu_trigger['metadata']['type']).to eq('Utilization')
      expect(cpu_trigger['metadata']['value']).to eq('70')
    end

    it 'should not set replica count on web deployment when KEDA is enabled' do
      t = HelmTemplate.new(keda_enabled_values.merge({ 'replicaCount' => 5 }))
      expect(t.dig('Deployment/optest-openproject-web', 'spec', 'replicas')).to be_nil
    end

    it 'should not add KEDA pause annotation to deployment' do
      t = HelmTemplate.new(keda_enabled_values.merge({ 'replicaCount' => 3 }))
      deployment = t.dig('Deployment/optest-openproject-web')
      
      annotations = deployment&.dig('metadata', 'annotations')
      if annotations
        expect(annotations['autoscaling.keda.sh/paused-replicas']).to be_nil
      end
    end
  end

  context 'when Prometheus scaling is configured' do
    it 'should create ScaledObject with Prometheus triggers' do
      t = HelmTemplate.new(prometheus_scaling_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      triggers = scaledobject['spec']['triggers']
      expect(triggers).to be_an(Array)
      expect(triggers.length).to eq(2)
    end

    it 'should configure requests in flight trigger' do
      t = HelmTemplate.new(prometheus_scaling_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      requests_trigger = scaledobject['spec']['triggers'].find { |t| t['metadata']['metricName'] == 'openproject_requests_in_flight' }
      expect(requests_trigger).not_to be_nil
      expect(requests_trigger['type']).to eq('prometheus')
      expect(requests_trigger['metadata']['serverAddress']).to eq('http://prometheus-server.monitoring.svc.cluster.local:80')
      expect(requests_trigger['metadata']['query']).to eq('avg(sum by (pod) (openproject_requests_in_flight{pod=~".*web.*"}))')
      expect(requests_trigger['metadata']['threshold']).to eq('30')
    end

    it 'should configure queue depth trigger' do
      t = HelmTemplate.new(prometheus_scaling_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      queue_trigger = scaledobject['spec']['triggers'].find { |t| t['metadata']['metricName'] == 'openproject_queue_depth' }
      expect(queue_trigger).not_to be_nil
      expect(queue_trigger['type']).to eq('prometheus')
      expect(queue_trigger['metadata']['query']).to eq('sum(openproject_background_jobs_queue_size)')
      expect(queue_trigger['metadata']['threshold']).to eq('50')
    end

    it 'should not set idle replica count (scale-to-zero disabled)' do
      t = HelmTemplate.new(prometheus_scaling_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      expect(scaledobject['spec']['idleReplicaCount']).to be_nil
    end
  end

  context 'when advanced KEDA configuration is provided' do
    it 'should configure fallback behavior' do
      t = HelmTemplate.new(advanced_keda_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      fallback = scaledobject['spec']['fallback']
      expect(fallback).not_to be_nil
      expect(fallback['failureThreshold']).to eq(3)
      expect(fallback['replicas']).to eq(2)
    end

    it 'should configure advanced HPA behavior' do
      t = HelmTemplate.new(advanced_keda_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      advanced = scaledobject['spec']['advanced']
      expect(advanced).not_to be_nil
      expect(advanced['restoreToOriginalReplicaCount']).to eq(true)
      expect(advanced['horizontalPodAutoscalerConfig']['behavior']['scaleDown']['stabilizationWindowSeconds']).to eq(300)
    end

    it 'should configure memory trigger' do
      t = HelmTemplate.new(advanced_keda_values)
      scaledobject = t.dig('ScaledObject/optest-openproject-web-scaler')
      
      triggers = scaledobject['spec']['triggers']
      memory_trigger = triggers.first
      expect(memory_trigger['type']).to eq('memory')
      expect(memory_trigger['metadata']['type']).to eq('Utilization')
      expect(memory_trigger['metadata']['value']).to eq('80')
    end
  end
end