# frozen_string_literal: true
require 'spec_helper'

describe 'asset server' do
  let(:values) { {} }
  let(:template) { HelmTemplate.new(values) }
  let(:deployment) { 'Deployment/optest-openproject-assets' }
  let(:caddy) { template.find_container(deployment, 'caddy') }
  let(:copy_assets) { template.find_container(deployment, 'copy-assets', true) }
  let(:caddyfile) { template['ConfigMap/optest-openproject-assets'].dig('data', 'Caddyfile') }
  let(:ingress_paths) { template['Ingress/optest-openproject']&.dig('spec', 'rules', 0, 'http', 'paths') }

  it 'copies the assets from the OpenProject image and serves them with Caddy' do
    expect(copy_assets['image']).to eq(template.find_image('Deployment/optest-openproject-web', 'openproject'))
    expect(copy_assets['command']).to eq(['cp', '-R', '/app/public/assets/.', '/srv/assets/'])
    expect(copy_assets['resources']).to eq(caddy['resources'])
    expect(copy_assets.dig('resources', 'requests', 'memory')).to eq('128Mi')
    expect(caddy['image']).to eq('docker.io/caddy:2.11.9-alpine')
    expect(caddy.dig('securityContext', 'readOnlyRootFilesystem')).to eq(true)
    expect(caddy.dig('livenessProbe', 'tcpSocket', 'port')).to eq('http')
    expect(caddy.dig('readinessProbe', 'tcpSocket', 'port')).to eq('http')
    expect(template.volumes(deployment)).to include({ 'name' => 'assets', 'emptyDir' => {} }, { 'name' => 'tmp', 'emptyDir' => {} })
  end

  it 'serves the precompressed files and falls back to the web service' do
    expect(caddyfile).to include('handle_path /assets/*', 'precompressed br gzip', 'reverse_proxy optest-openproject:8080')
    expect(caddyfile).to include('header_up X-Forwarded-Proto {header.X-Forwarded-Proto}')
  end

  it 'compresses assets without a precompressed file unless disabled' do
    expect(caddyfile).to include('encode zstd gzip')

    disabled = HelmTemplate.new('assetServer' => { 'encode' => false })
    expect(disabled['ConfigMap/optest-openproject-assets'].dig('data', 'Caddyfile')).not_to include('encode')
  end

  it 'caches only fingerprinted assets for a long time' do
    expect(caddyfile).to include('header @fingerprinted Cache-Control "public, max-age=31536000, immutable"',
                                 'header @unfingerprinted Cache-Control "no-cache"')
  end

  it 'does not deploy a NetworkPolicy by default' do
    expect(template['NetworkPolicy/optest-openproject-assets']).to be_nil
  end

  context 'with restricted network policies' do
    let(:values) { { 'networkPolicy' => { 'enabled' => true, 'allowExternal' => false, 'allowExternalEgress' => false } } }
    let(:policy) { template['NetworkPolicy/optest-openproject-assets']['spec'] }

    it 'allows Ingress traffic, DNS and the fallback to the web pods' do
      expect(policy.dig('podSelector', 'matchLabels')).to include('openproject/process' => 'assets')
      expect(policy.dig('ingress', 0, 'ports')).to eq([{ 'port' => 8080, 'protocol' => 'TCP' }])
      expect(policy['egress']).to include(hash_including('ports' => [{ 'port' => 53, 'protocol' => 'UDP' }, { 'port' => 53, 'protocol' => 'TCP' }]),
                                          hash_including('to' => [{ 'podSelector' => { 'matchLabels' => hash_including('openproject/process' => 'web') } }],
                                                         'ports' => [{ 'port' => 8080, 'protocol' => 'TCP' }]))
    end

    it 'lets the asset server reach the web pods' do
      from = template['NetworkPolicy/optest-openproject-web'].dig('spec', 'ingress', 0, 'from', 0, 'podSelector', 'matchLabels')
      labels = template.dig(deployment, 'spec', 'template', 'metadata', 'labels')
      expect(labels).to include(from)
    end
  end

  it 'routes the assets path of the Ingress to the asset server' do
    expect(ingress_paths).to include(hash_including('path' => '/assets', 'pathType' => 'Prefix',
                                                    'backend' => { 'service' => { 'name' => 'optest-openproject-assets', 'port' => { 'name' => 'http' } } }))
    expect(template['Service/optest-openproject-assets'].dig('spec', 'selector')).to include('openproject/process' => 'assets')
  end

  it 'restarts the asset server when the Caddyfile changes' do
    changed = HelmTemplate.new('openproject' => { 'railsRelativeUrlRoot' => '/op' })
    expect(changed.template_annotations(deployment)['checksum/config']).not_to eq(template.template_annotations(deployment)['checksum/config'])
  end

  it 'keeps custom labels out of immutable selectors' do
    changed = HelmTemplate.new('commonLabels' => { 'team' => 'operations' })
    expect(changed.spec(deployment)['selector']).to eq(template.spec(deployment)['selector'])
  end

  context 'with a relative URL root' do
    let(:values) { { 'openproject' => { 'railsRelativeUrlRoot' => '/op' } } }

    it 'serves and routes the prefixed assets path' do
      expect(caddyfile).to include('handle_path /op/assets/*')
      expect(ingress_paths).to include(hash_including('path' => '/op/assets'))
    end
  end

  context 'with custom settings' do
    let(:values) do
      { 'assetServer' => {
        'replicas' => 2,
        'resourcesPreset' => 'none',
        'image' => { 'sha256' => 'abc123', 'imagePullPolicy' => 'Always' },
        'probes' => { 'liveness' => { 'enabled' => false }, 'readiness' => { 'periodSeconds' => 3 } }
      } }
    end

    it 'supports replicas, the image digest, resource and probe overrides' do
      expect(template.spec(deployment)['replicas']).to eq(2)
      expect(caddy['image']).to eq('docker.io/caddy@sha256:abc123')
      expect(caddy['imagePullPolicy']).to eq('Always')
      expect(caddy).not_to have_key('resources')
      expect(caddy).not_to have_key('livenessProbe')
      expect(caddy.dig('readinessProbe', 'periodSeconds')).to eq(3)
    end
  end

  [
    ['disabled', { 'assetServer' => { 'enabled' => false } }],
    ['without the chart Ingress', { 'ingress' => { 'enabled' => false } }]
  ].each do |description, settings|
    context description do
      let(:values) { settings.merge('networkPolicy' => { 'enabled' => true }) }

      it 'does not deploy the asset server and leaves the Ingress unchanged' do
        expect(template[deployment]).to be_nil
        expect(template['Service/optest-openproject-assets']).to be_nil
        expect(template['ConfigMap/optest-openproject-assets']).to be_nil
        expect(template['NetworkPolicy/optest-openproject-assets']).to be_nil
        expect(Array(ingress_paths).map { |path| path['path'] }).not_to include('/assets')
      end
    end
  end
end
