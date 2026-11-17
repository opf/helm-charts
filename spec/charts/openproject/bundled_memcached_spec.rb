# frozen_string_literal: true
require 'spec_helper'

describe 'bundled Memcached deployment' do
  let(:values) { {} }
  let(:template) { HelmTemplate.new(values) }
  let(:deployment) { 'Deployment/optest-openproject-cache' }
  let(:container) { template.find_container(deployment, 'memcached') }

  it 'runs one non-root official Memcached with UDP disabled' do
    expect(container['image']).to eq('docker.io/memcached:1.6.45-alpine')
    expect(container['args']).to eq(['memcached', '-m', '64', '-U', '0'])
    expect(container.dig('securityContext', 'runAsUser')).to eq(11211)
    expect(container.dig('securityContext', 'readOnlyRootFilesystem')).to eq(true)
    expect(template.spec(deployment)['replicas']).to eq(1)
    expect(template.spec(deployment).dig('strategy', 'type')).to eq('Recreate')
    expect(container.dig('livenessProbe', 'tcpSocket', 'port')).to eq('memcached')
    expect(container.dig('readinessProbe', 'tcpSocket', 'port')).to eq('memcached')
    expect(template['Deployment/optest-memcached']).to be_nil
  end

  it 'uses a private TCP service and the same name in application configuration' do
    service = template['Service/optest-openproject-cache']
    expect(service.dig('spec', 'type')).to eq('ClusterIP')
    expect(service.dig('spec', 'ports')).to eq([{ 'name' => 'memcached', 'port' => 11211, 'targetPort' => 'memcached', 'protocol' => 'TCP' }])
    expect(template['Secret/optest-openproject-memcached'].dig('stringData', 'OPENPROJECT_CACHE__MEMCACHE__SERVER')).to eq('optest-openproject-cache:11211')
  end

  it 'uses the application namespace override for all cache resources' do
    changed = HelmTemplate.new('namespaceOverride' => 'application', 'networkPolicy' => { 'enabled' => true })
    %w[Deployment Service NetworkPolicy].each do |kind|
      expect(changed["#{kind}/optest-openproject-cache"].dig('metadata', 'namespace')).to eq('application')
    end
  end

  it 'quotes numeric and boolean pod annotations like other application workloads' do
    changed = HelmTemplate.new('podAnnotations' => { 'build' => 123, 'enabled' => true })
    expect(changed.template_annotations(deployment)).to include('build' => '123', 'enabled' => 'true')
  end

  it 'keeps custom labels out of immutable selectors' do
    changed = HelmTemplate.new('commonLabels' => { 'team' => 'operations' })
    expect(changed.spec(deployment)['selector']).to eq(template.spec(deployment)['selector'])
  end

  it 'does not silently remove configured SASL authentication' do
    authenticated = HelmTemplate.new('memcached' => { 'auth' => { 'enabled' => true } })
    expect(authenticated.exit_code).not_to eq(0)
    expect(authenticated.stderr).to include('external authenticated cache')
  end

  context 'with external Memcached' do
    let(:values) { { 'memcached' => { 'bundled' => false, 'connection' => { 'host' => 'cache.example', 'port' => 11212 } } } }

    it 'keeps external configuration without deploying a bundled cache' do
      expect(template[deployment]).to be_nil
      expect(template['Service/optest-openproject-cache']).to be_nil
      expect(template['NetworkPolicy/optest-openproject-cache']).to be_nil
      expect(template['Secret/optest-openproject-memcached'].dig('stringData', 'OPENPROJECT_CACHE__MEMCACHE__SERVER')).to eq('cache.example:11212')
    end
  end

  context 'with restricted egress' do
    let(:values) { { 'networkPolicy' => { 'enabled' => true, 'allowExternalEgress' => false } } }

    it 'allows application pods to reach the bundled cache' do
      expect(template['NetworkPolicy/optest-openproject-cache']).not_to be_nil
      %w[web worker-default cron seeder].each do |process|
        rules = template["NetworkPolicy/optest-openproject-#{process}"].dig('spec', 'egress')
        expect(rules).to include(hash_including('ports' => [{ 'port' => 11211, 'protocol' => 'TCP' }]))
      end
    end
  end

  context 'with custom settings' do
    let(:values) do
      { 'memcached' => { 'resourcesPreset' => 'none', 'memoryLimit' => 128,
        'extraArgs' => ['-I', '2m'], 'nodeSelector' => { 'cache' => 'true' },
        'image' => { 'sha256' => 'abc123', 'imagePullPolicy' => 'Always' },
        'probes' => { 'readiness' => { 'periodSeconds' => 3 } } } }
    end

    it 'supports memory, image, resource, scheduling and probe settings' do
      expect(container['image']).to eq('docker.io/memcached@sha256:abc123')
      expect(container['args']).to eq(['memcached', '-m', '128', '-U', '0', '-I', '2m'])
      expect(container).not_to have_key('resources')
      expect(template.template_spec(deployment)['nodeSelector']).to eq('cache' => 'true')
      expect(container.dig('readinessProbe', 'periodSeconds')).to eq(3)
    end
  end
end
