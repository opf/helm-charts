require_relative '../../spec_helper'

describe 'openproject metrics' do
  let(:default_values) do
    HelmTemplate.with_defaults({})
  end

  let(:metrics_enabled_values) do
    HelmTemplate.with_defaults({
      'metrics' => {
        'enabled' => true,
        'path' => '/api/metrics',
        'port' => 8080
      }
    })
  end

  let(:servicemonitor_enabled_values) do
    HelmTemplate.with_defaults({
      'metrics' => {
        'enabled' => true,
        'path' => '/api/metrics',
        'port' => 8080,
        'serviceMonitor' => {
          'enabled' => true,
          'interval' => '15s',
          'scrapeTimeout' => '5s',
          'namespace' => 'monitoring',
          'labels' => {
            'monitoring' => 'prometheus'
          },
          'annotations' => {
            'meta.helm.sh/release-name' => 'prometheus'
          }
        }
      }
    })
  end

  context 'when metrics are disabled' do
    it 'should not add prometheus annotations to pods' do
      t = HelmTemplate.new(default_values)
      deployment = t.dig('optest-openproject-web', 'Deployment')
      annotations = deployment['spec']['template']['metadata']['annotations']
      
      expect(annotations).not_to have_key('prometheus.io/scrape')
      expect(annotations).not_to have_key('prometheus.io/path')
      expect(annotations).not_to have_key('prometheus.io/port')
    end

    it 'should not add metrics port to deployment' do
      t = HelmTemplate.new(default_values)
      deployment = t.dig('optest-openproject-web', 'Deployment')
      container = deployment['spec']['template']['spec']['containers'].first
      
      metrics_port = container['ports'].find { |p| p['name'] == 'metrics' }
      expect(metrics_port).to be_nil
    end

    it 'should not add metrics port to service' do
      t = HelmTemplate.new(default_values)
      service = t.dig('optest-openproject', 'Service')
      
      metrics_port = service['spec']['ports'].find { |p| p['name'] == 'metrics' }
      expect(metrics_port).to be_nil
    end

    it 'should not create ServiceMonitor' do
      t = HelmTemplate.new(default_values)
      expect(t.dig('optest-openproject-metrics', 'ServiceMonitor')).to be_nil
    end
  end

  context 'when metrics are enabled' do
    it 'should add prometheus annotations to pods' do
      t = HelmTemplate.new(metrics_enabled_values)
      deployment = t.dig('optest-openproject-web', 'Deployment')
      annotations = deployment['spec']['template']['metadata']['annotations']
      
      expect(annotations['prometheus.io/scrape']).to eq('true')
      expect(annotations['prometheus.io/path']).to eq('/api/metrics')
      expect(annotations['prometheus.io/port']).to eq('8080')
    end

    it 'should add metrics port to deployment container' do
      t = HelmTemplate.new(metrics_enabled_values)
      deployment = t.dig('optest-openproject-web', 'Deployment')
      container = deployment['spec']['template']['spec']['containers'].first
      
      metrics_port = container['ports'].find { |p| p['name'] == 'metrics' }
      expect(metrics_port).not_to be_nil
      expect(metrics_port['containerPort']).to eq(8080)
      expect(metrics_port['protocol']).to eq('TCP')
    end

    it 'should add metrics port to service' do
      t = HelmTemplate.new(metrics_enabled_values)
      service = t.dig('optest-openproject', 'Service')
      
      metrics_port = service['spec']['ports'].find { |p| p['name'] == 'metrics' }
      expect(metrics_port).not_to be_nil
      expect(metrics_port['port']).to eq(8080)
      expect(metrics_port['targetPort']).to eq('metrics')
      expect(metrics_port['protocol']).to eq('TCP')
    end
  end

  context 'when ServiceMonitor is enabled' do
    it 'should create ServiceMonitor resource' do
      t = HelmTemplate.new(servicemonitor_enabled_values)
      servicemonitor = t.dig('optest-openproject-metrics', 'ServiceMonitor')
      
      expect(servicemonitor).not_to be_nil
      expect(servicemonitor['apiVersion']).to eq('monitoring.coreos.com/v1')
      expect(servicemonitor['kind']).to eq('ServiceMonitor')
    end

    it 'should configure ServiceMonitor metadata' do
      t = HelmTemplate.new(servicemonitor_enabled_values)
      servicemonitor = t.dig('optest-openproject-metrics', 'ServiceMonitor')
      
      expect(servicemonitor['metadata']['namespace']).to eq('monitoring')
      expect(servicemonitor['metadata']['labels']['monitoring']).to eq('prometheus')
      expect(servicemonitor['metadata']['annotations']['meta.helm.sh/release-name']).to eq('prometheus')
    end

    it 'should configure ServiceMonitor endpoint' do
      t = HelmTemplate.new(servicemonitor_enabled_values)
      servicemonitor = t.dig('optest-openproject-metrics', 'ServiceMonitor')
      
      endpoint = servicemonitor['spec']['endpoints'].first
      expect(endpoint['port']).to eq('metrics')
      expect(endpoint['path']).to eq('/api/metrics')
      expect(endpoint['interval']).to eq('15s')
      expect(endpoint['scrapeTimeout']).to eq('5s')
      expect(endpoint['honorLabels']).to eq(false)
    end

    it 'should configure ServiceMonitor selector' do
      t = HelmTemplate.new(servicemonitor_enabled_values)
      servicemonitor = t.dig('optest-openproject-metrics', 'ServiceMonitor')
      
      expect(servicemonitor['spec']['namespaceSelector']['matchNames']).to include('default')
      expect(servicemonitor['spec']['selector']['matchLabels']).to include('app.kubernetes.io/name' => 'openproject')
    end

    it 'should set jobLabel' do
      t = HelmTemplate.new(servicemonitor_enabled_values)
      servicemonitor = t.dig('optest-openproject-metrics', 'ServiceMonitor')
      
      expect(servicemonitor['spec']['jobLabel']).to eq('optest-openproject')
    end
  end

  context 'when metrics are enabled but ServiceMonitor is disabled' do
    it 'should not create ServiceMonitor' do
      metrics_only_values = metrics_enabled_values.dup
      metrics_only_values['metrics']['serviceMonitor'] = { 'enabled' => false }
      
      t = HelmTemplate.new(metrics_only_values)
      expect(t.dig('optest-openproject-metrics', 'ServiceMonitor')).to be_nil
    end
  end
end