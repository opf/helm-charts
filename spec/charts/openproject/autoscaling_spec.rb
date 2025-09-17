require_relative '../../spec_helper'

describe 'openproject HPA autoscaling' do
  let(:default_values) do
    HelmTemplate.with_defaults({})
  end

  let(:hpa_enabled_values) do
    HelmTemplate.with_defaults({
      'autoscaling' => {
        'enabled' => true,
        'minReplicas' => 2,
        'maxReplicas' => 10,
        'targetCPUUtilizationPercentage' => 70
      }
    })
  end

  let(:hpa_with_memory_values) do
    HelmTemplate.with_defaults({
      'autoscaling' => {
        'enabled' => true,
        'minReplicas' => 1,
        'maxReplicas' => 20,
        'targetCPUUtilizationPercentage' => 70,
        'targetMemoryUtilizationPercentage' => 80
      }
    })
  end

  let(:hpa_custom_metrics_values) do
    HelmTemplate.with_defaults({
      'autoscaling' => {
        'enabled' => true,
        'minReplicas' => 2,
        'maxReplicas' => 15,
        'targetCPUUtilizationPercentage' => 70,
        'customMetrics' => [
          {
            'type' => 'Pods',
            'pods' => {
              'metric' => {
                'name' => 'puma_request_backlog_avg_1min'
              },
              'target' => {
                'type' => 'AverageValue',
                'averageValue' => '2'
              }
            }
          }
        ]
      }
    })
  end

  let(:hpa_advanced_behavior_values) do
    HelmTemplate.with_defaults({
      'autoscaling' => {
        'enabled' => true,
        'minReplicas' => 3,
        'maxReplicas' => 15,
        'targetCPUUtilizationPercentage' => 60,
        'behavior' => {
          'scaleDown' => {
            'stabilizationWindowSeconds' => 300,
            'policies' => [
              {
                'type' => 'Pods',
                'value' => 1,
                'periodSeconds' => 60
              }
            ],
            'selectPolicy' => 'Min'
          },
          'scaleUp' => {
            'stabilizationWindowSeconds' => 60,
            'policies' => [
              {
                'type' => 'Percent',
                'value' => 50,
                'periodSeconds' => 60
              }
            ],
            'selectPolicy' => 'Max'
          }
        }
      }
    })
  end

  let(:hpa_multiple_custom_metrics_values) do
    HelmTemplate.with_defaults({
      'autoscaling' => {
        'enabled' => true,
        'minReplicas' => 2,
        'maxReplicas' => 20,
        'customMetrics' => [
          {
            'type' => 'Pods',
            'pods' => {
              'metric' => {
                'name' => 'puma_request_backlog_avg_1min'
              },
              'target' => {
                'type' => 'AverageValue',
                'averageValue' => '2'
              }
            }
          },
          {
            'type' => 'External',
            'external' => {
              'metric' => {
                'name' => 'queue_depth',
                'selector' => {
                  'matchLabels' => {
                    'app' => 'openproject'
                  }
                }
              },
              'target' => {
                'type' => 'Value',
                'value' => '50'
              }
            }
          }
        ]
      }
    })
  end

  context 'when autoscaling is disabled' do
    it 'should not create HorizontalPodAutoscaler resource' do
      t = HelmTemplate.new(default_values)
      expect(t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')).to be_nil
    end

    it 'should set replica count on web deployment' do
      t = HelmTemplate.new(default_values.merge({ 'replicaCount' => 3 }))
      expect(t.dig('Deployment/optest-openproject-web', 'spec', 'replicas')).to eq(3)
    end
  end

  context 'when autoscaling is enabled' do
    it 'should create HorizontalPodAutoscaler resource' do
      t = HelmTemplate.new(hpa_enabled_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      expect(hpa).not_to be_nil
      expect(hpa['apiVersion']).to eq('autoscaling/v2')
      expect(hpa['kind']).to eq('HorizontalPodAutoscaler')
    end

    it 'should configure HPA target reference' do
      t = HelmTemplate.new(hpa_enabled_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      target_ref = hpa['spec']['scaleTargetRef']
      expect(target_ref['apiVersion']).to eq('apps/v1')
      expect(target_ref['kind']).to eq('Deployment')
      expect(target_ref['name']).to eq('optest-openproject-web')
    end

    it 'should set min and max replica counts' do
      t = HelmTemplate.new(hpa_enabled_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      expect(hpa['spec']['minReplicas']).to eq(2)
      expect(hpa['spec']['maxReplicas']).to eq(10)
    end

    it 'should configure CPU metric' do
      t = HelmTemplate.new(hpa_enabled_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      metrics = hpa['spec']['metrics']
      expect(metrics).to be_an(Array)
      expect(metrics.length).to eq(1)

      cpu_metric = metrics.first
      expect(cpu_metric['type']).to eq('Resource')
      expect(cpu_metric['resource']['name']).to eq('cpu')
      expect(cpu_metric['resource']['target']['type']).to eq('Utilization')
      expect(cpu_metric['resource']['target']['averageUtilization']).to eq(70)
    end

    it 'should not set replica count on web deployment when autoscaling is enabled' do
      t = HelmTemplate.new(hpa_enabled_values.merge({ 'replicaCount' => 5 }))
      expect(t.dig('Deployment/optest-openproject-web', 'spec', 'replicas')).to be_nil
    end
  end

  context 'when CPU and memory scaling is configured' do
    it 'should configure both CPU and memory metrics' do
      t = HelmTemplate.new(hpa_with_memory_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      metrics = hpa['spec']['metrics']
      expect(metrics).to be_an(Array)
      expect(metrics.length).to eq(2)

      # Find CPU metric
      cpu_metric = metrics.find { |m| m['resource'] && m['resource']['name'] == 'cpu' }
      expect(cpu_metric).not_to be_nil
      expect(cpu_metric['type']).to eq('Resource')
      expect(cpu_metric['resource']['target']['averageUtilization']).to eq(70)

      # Find memory metric
      memory_metric = metrics.find { |m| m['resource'] && m['resource']['name'] == 'memory' }
      expect(memory_metric).not_to be_nil
      expect(memory_metric['type']).to eq('Resource')
      expect(memory_metric['resource']['target']['averageUtilization']).to eq(80)
    end
  end

  context 'when custom metrics scaling is configured' do
    it 'should create HPA with custom metrics' do
      t = HelmTemplate.new(hpa_custom_metrics_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      metrics = hpa['spec']['metrics']
      expect(metrics).to be_an(Array)
      expect(metrics.length).to eq(2) # CPU + custom metric
    end

    it 'should configure pods-type custom metric' do
      t = HelmTemplate.new(hpa_custom_metrics_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      # Find custom metric
      custom_metric = hpa['spec']['metrics'].find { |m| m['type'] == 'Pods' }
      expect(custom_metric).not_to be_nil
      expect(custom_metric['pods']['metric']['name']).to eq('puma_request_backlog_avg_1min')
      expect(custom_metric['pods']['target']['type']).to eq('AverageValue')
      expect(custom_metric['pods']['target']['averageValue']).to eq(2)
    end

    it 'should still include CPU metric as fallback' do
      t = HelmTemplate.new(hpa_custom_metrics_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      # Find CPU metric
      cpu_metric = hpa['spec']['metrics'].find { |m| m['resource'] && m['resource']['name'] == 'cpu' }
      expect(cpu_metric).not_to be_nil
      expect(cpu_metric['resource']['target']['averageUtilization']).to eq(70)
    end
  end

  context 'when multiple custom metrics are configured' do
    it 'should configure all custom metrics types' do
      t = HelmTemplate.new(hpa_multiple_custom_metrics_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      metrics = hpa['spec']['metrics']
      expect(metrics.length).to eq(2) # Two custom metrics (no CPU because not specified in this test)

      # Find Pods metric
      pods_metric = metrics.find { |m| m['type'] == 'Pods' }
      expect(pods_metric).not_to be_nil
      expect(pods_metric['pods']['metric']['name']).to eq('puma_request_backlog_avg_1min')

      # Find External metric
      external_metric = metrics.find { |m| m['type'] == 'External' }
      expect(external_metric).not_to be_nil
      expect(external_metric['external']['metric']['name']).to eq('queue_depth')
      expect(external_metric['external']['target']['type']).to eq('Value')
      expect(external_metric['external']['target']['value']).to eq(50)
    end
  end

  context 'when advanced scaling behavior is configured' do
    it 'should configure behavior section' do
      t = HelmTemplate.new(hpa_advanced_behavior_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      behavior = hpa['spec']['behavior']
      expect(behavior).not_to be_nil
    end

    it 'should configure scale down behavior' do
      t = HelmTemplate.new(hpa_advanced_behavior_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      scale_down = hpa['spec']['behavior']['scaleDown']
      expect(scale_down['stabilizationWindowSeconds']).to eq(300)
      expect(scale_down['selectPolicy']).to eq('Min')

      policies = scale_down['policies']
      expect(policies).to be_an(Array)
      expect(policies.first['type']).to eq('Pods')
      expect(policies.first['value']).to eq(1)
      expect(policies.first['periodSeconds']).to eq(60)
    end

    it 'should configure scale up behavior' do
      t = HelmTemplate.new(hpa_advanced_behavior_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      scale_up = hpa['spec']['behavior']['scaleUp']
      expect(scale_up['stabilizationWindowSeconds']).to eq(60)
      expect(scale_up['selectPolicy']).to eq('Max')

      policies = scale_up['policies']
      expect(policies).to be_an(Array)
      expect(policies.first['type']).to eq('Percent')
      expect(policies.first['value']).to eq(50)
      expect(policies.first['periodSeconds']).to eq(60)
    end
  end

  context 'HPA metadata and labels' do
    it 'should have correct metadata' do
      t = HelmTemplate.new(hpa_enabled_values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      expect(hpa['metadata']['name']).to eq('optest-openproject-web-hpa')
      expect(hpa['metadata']['labels']['app.kubernetes.io/name']).to eq('openproject')
      expect(hpa['metadata']['labels']['openproject/process']).to eq('web')
    end
  end

  context 'validation edge cases' do
    it 'should handle empty customMetrics array' do
      values = HelmTemplate.with_defaults({
        'autoscaling' => {
          'enabled' => true,
          'minReplicas' => 1,
          'maxReplicas' => 5,
          'targetCPUUtilizationPercentage' => 70,
          'customMetrics' => []
        }
      })

      t = HelmTemplate.new(values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      metrics = hpa['spec']['metrics']
      expect(metrics.length).to eq(1) # Only CPU metric
      expect(metrics.first['type']).to eq('Resource')
    end

    it 'should handle missing targetCPUUtilizationPercentage' do
      values = HelmTemplate.with_defaults({
        'autoscaling' => {
          'enabled' => true,
          'minReplicas' => 1,
          'maxReplicas' => 5
        }
      })

      t = HelmTemplate.new(values)
      hpa = t.dig('HorizontalPodAutoscaler/optest-openproject-web-hpa')

      # Should have no metrics if no CPU target is set
      metrics = hpa['spec']['metrics']
      expect(metrics).to be_nil.or be_empty
    end
  end
end