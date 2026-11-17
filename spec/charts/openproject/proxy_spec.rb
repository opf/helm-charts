# frozen_string_literal: true
require 'spec_helper'

describe 'Caddy web proxy' do
  let(:values) { {} }
  let(:template) { HelmTemplate.new(values) }
  let(:deployment) { 'Deployment/optest-openproject-web' }
  let(:proxy) { template.find_container(deployment, 'proxy') }
  let(:config) { template['ConfigMap/optest-openproject-proxy'].dig('data', 'Caddyfile') }

  it 'routes the existing HTTP service through the proxy and leaves metrics separate' do
    template = HelmTemplate.new('metrics' => { 'enabled' => true })
    ports = template['Service/optest-openproject'].dig('spec', 'ports')
    expect(ports).to include(hash_including('name' => 'http', 'port' => 8080, 'targetPort' => 'http'))
    expect(ports).to include(hash_including('name' => 'metrics', 'targetPort' => 'metrics'))
    expect(template.find_container(deployment, 'openproject')['ports']).to include(hash_including('name' => 'puma-http', 'containerPort' => 8080))
  end

  it 'compresses responses without rewriting application paths or serving local files' do
    expect(config).to include('encode zstd gzip', 'reverse_proxy 127.0.0.1:8080', 'auto_https off', 'admin off')
    expect(config).not_to include('file_server', 'handle_path', 'header_up')
    expect(proxy['image']).to eq('docker.io/caddy:2.11.9-alpine')
    expect(proxy['volumeMounts']).to include(hash_including('name' => 'proxy-tmp', 'mountPath' => '/tmp'))
  end

  it 'uses the configured application container port as its upstream' do
    changed = HelmTemplate.new('service' => { 'ports' => { 'http' => { 'containerPort' => 9080 } } })
    expect(changed['ConfigMap/optest-openproject-proxy'].dig('data', 'Caddyfile')).to include('reverse_proxy 127.0.0.1:9080')
  end

  it 'only trusts configured proxies and parses forwarded addresses from the trusted end' do
    expect(config).to include('trusted_proxies static private_ranges', 'trusted_proxies_strict')
    external = HelmTemplate.new('proxy' => { 'trustedProxies' => [] })
    expect(external['ConfigMap/optest-openproject-proxy'].dig('data', 'Caddyfile')).not_to include('trusted_proxies')
  end

  it 'keeps a stable service target port across sidecar enablement' do
    disabled = HelmTemplate.new('proxy' => { 'enabled' => false })
    expect(disabled['Service/optest-openproject'].dig('spec', 'ports')).to eq(template['Service/optest-openproject'].dig('spec', 'ports'))
    expect(proxy['ports']).to include(hash_including('name' => 'http', 'containerPort' => 8081))
  end

  it 'deploys the proxy configuration in the overridden application namespace' do
    namespaced = HelmTemplate.new('namespaceOverride' => 'application')
    expect(namespaced['ConfigMap/optest-openproject-proxy'].dig('metadata', 'namespace')).to eq(namespaced[deployment].dig('metadata', 'namespace'))
  end

  it 'does not add unfiltered request logging' do
    expect(config.lines.map(&:strip)).not_to include('log')
  end

  it 'restarts web pods when proxy settings change' do
    changed = HelmTemplate.new('proxy' => { 'trustedProxies' => ['10.42.0.0/16'] })
    expect(template.template_annotations(deployment)['checksum/proxy']).not_to eq(changed.template_annotations(deployment)['checksum/proxy'])
  end

  it 'allows proxy traffic through the web network policy' do
    restricted = HelmTemplate.new('networkPolicy' => { 'enabled' => true })
    ports = restricted['NetworkPolicy/optest-openproject-web'].dig('spec', 'ingress', 0, 'ports')
    expect(ports).to include('port' => 8081)
  end

  context 'with proxy disabled' do
    let(:values) { { 'proxy' => { 'enabled' => false } } }

    it 'connects the Service to Puma without deploying proxy resources' do
      expect(proxy).to be_nil
      expect(template['ConfigMap/optest-openproject-proxy']).to be_nil
      expect(template['Service/optest-openproject'].dig('spec', 'ports', 0, 'targetPort')).to eq('http')
      expect(template.volumes(deployment).map { |volume| volume['name'] }).not_to include('proxy-config', 'proxy-tmp')
    end
  end

  context 'with custom settings' do
    let(:values) do
      { 'proxy' => {
        'port' => 9081,
        'resourcesPreset' => 'none',
        'image' => { 'sha256' => 'abc123', 'imagePullPolicy' => 'Always' },
        'probes' => { 'liveness' => { 'enabled' => false }, 'readiness' => { 'periodSeconds' => 3 } }
      } }
    end

    it 'supports the image digest, port, resource and probe overrides' do
      expect(proxy['image']).to eq('docker.io/caddy@sha256:abc123')
      expect(proxy['imagePullPolicy']).to eq('Always')
      expect(config).to include(':9081')
      expect(proxy).not_to have_key('resources')
      expect(proxy).not_to have_key('livenessProbe')
      expect(proxy.dig('readinessProbe', 'periodSeconds')).to eq(3)
    end
  end
end
