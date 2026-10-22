# frozen_string_literal: true
require 'spec_helper'

describe 'configuring anycable' do
  let(:template) { HelmTemplate.new(default_values) }

  def env_of(deployment_name)
    template.dig("Deployment/#{deployment_name}", 'spec', 'template', 'spec', 'containers').first['env']
  end

  def env_var(deployment_name, name)
    env_of(deployment_name).find { |e| e['name'] == name }
  end

  context 'with the default values' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: true
        YAML
      )
    end

    it 'does not deploy anycable', :aggregate_failures do
      expect(template['Deployment/optest-openproject-anycable']).to be_nil
      expect(template['Service/optest-openproject-anycable']).to be_nil
      expect(template['Secret/anycable-secret-auto-generated']).to be_nil
    end

    it 'does not configure live updates in OpenProject', :aggregate_failures do
      expect(template.dig('Secret/optest-openproject-core', 'stringData')).not_to include('ANYCABLE_WEBSOCKET_URL')
      expect(env_var('optest-openproject-web', 'ANYCABLE_SECRET')).to be_nil
    end

    it 'does not route any paths to anycable' do
      paths = template.dig('Ingress/optest-openproject', 'spec', 'rules').first['http']['paths'].map { |p| p['path'] }

      expect(paths).not_to include('/cable', '/events', '/_anycable')
    end
  end

  context 'when anycable and live updates are enabled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: true
          anycable:
            enabled: true
          openproject:
            live_updates:
              enabled: true
        YAML
      )
    end

    it 'deploys anycable with its service', :aggregate_failures do
      expect(template['Deployment/optest-openproject-anycable']).not_to be_nil
      expect(template.dig('Service/optest-openproject-anycable', 'spec', 'ports').first['port']).to eq 2345
    end

    it 'routes the WebSocket, SSE and RPC paths to anycable', :aggregate_failures do
      paths = template.dig('Ingress/optest-openproject', 'spec', 'rules').first['http']['paths']
      anycable_paths = paths.select { |p| p.dig('backend', 'service', 'name') == 'optest-openproject-anycable' }

      expect(anycable_paths.map { |p| p['path'] }).to eq ['/cable', '/events', '/_anycable']
      expect(paths.last['path']).to eq '/'
    end

    it 'auto generates a secret' do
      expect(template.dig('Secret/anycable-secret-auto-generated', 'stringData', 'secret')).not_to be_empty
    end

    it 'shares the auto generated secret between anycable and OpenProject', :aggregate_failures do
      %w[optest-openproject-anycable optest-openproject-web optest-openproject-worker-default].each do |deployment|
        secret_env = env_var(deployment, 'ANYCABLE_SECRET')

        expect(secret_env.dig('valueFrom', 'secretKeyRef')).to eq('name' => 'anycable-secret-auto-generated', 'key' => 'secret')
      end
    end

    it 'configures anycable to call OpenProject and serve the default paths', :aggregate_failures do
      expect(env_var('optest-openproject-anycable', 'ANYCABLE_RPC_HOST')['value']).to eq 'http://optest-openproject:8080/_anycable'
      expect(env_var('optest-openproject-anycable', 'ANYCABLE_PATH')['value']).to eq '/cable'
      expect(env_var('optest-openproject-anycable', 'ANYCABLE_SSE_PATH')['value']).to eq '/events'
    end

    it 'configures OpenProject to use anycable', :aggregate_failures do
      core = template.dig('Secret/optest-openproject-core', 'stringData')

      expect(core['ANYCABLE_WEBSOCKET_URL']).to eq '/cable'
      expect(core['ANYCABLE_HTTP_RPC']).to eq 'true'
      expect(core['ANYCABLE_HTTP_BROADCAST_URL']).to eq 'http://optest-openproject-anycable:2345/_broadcast'
    end
  end

  context 'when OpenProject is served under a path prefix' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: true
          anycable:
            enabled: true
          openproject:
            railsRelativeUrlRoot: /op/
            live_updates:
              enabled: true
        YAML
      )
    end

    it 'prefixes the paths everywhere', :aggregate_failures do
      paths = template.dig('Ingress/optest-openproject', 'spec', 'rules').first['http']['paths'].map { |p| p['path'] }

      expect(paths).to include('/op/cable', '/op/events', '/op/_anycable')
      expect(template.dig('Secret/optest-openproject-core', 'stringData', 'ANYCABLE_WEBSOCKET_URL')).to eq '/op/cable'
      expect(env_var('optest-openproject-anycable', 'ANYCABLE_PATH')['value']).to eq '/op/cable'
      expect(env_var('optest-openproject-anycable', 'ANYCABLE_SSE_PATH')['value']).to eq '/op/events'
      expect(env_var('optest-openproject-anycable', 'ANYCABLE_RPC_HOST')['value']).to eq 'http://optest-openproject:8080/op/_anycable'
    end
  end

  context 'with the anycable secret defined' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          anycable:
            enabled: true
            auth:
              existingSecret: ac-secret
          openproject:
            live_updates:
              enabled: true
        YAML
      )
    end

    it 'does not auto generate a secret' do
      expect(template['Secret/anycable-secret-auto-generated']).to be_nil
    end

    it 'uses the named secret in anycable and OpenProject', :aggregate_failures do
      %w[optest-openproject-anycable optest-openproject-web].each do |deployment|
        expect(env_var(deployment, 'ANYCABLE_SECRET').dig('valueFrom', 'secretKeyRef', 'name')).to eq 'ac-secret'
      end
    end
  end

  context 'with an external anycable server' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          openproject:
            live_updates:
              enabled: true
              broadcastUrl: http://anycable.other-namespace:2345/_broadcast
              auth:
                existingSecret: external-secret
        YAML
      )
    end

    it 'does not deploy anycable nor generate a secret', :aggregate_failures do
      expect(template['Deployment/optest-openproject-anycable']).to be_nil
      expect(template['Secret/anycable-secret-auto-generated']).to be_nil
    end

    it 'configures OpenProject with the external server', :aggregate_failures do
      core = template.dig('Secret/optest-openproject-core', 'stringData')

      expect(core['ANYCABLE_WEBSOCKET_URL']).to eq '/cable'
      expect(core['ANYCABLE_HTTP_BROADCAST_URL']).to eq 'http://anycable.other-namespace:2345/_broadcast'
      expect(env_var('optest-openproject-web', 'ANYCABLE_SECRET').dig('valueFrom', 'secretKeyRef', 'name')).to eq 'external-secret'
    end
  end

  context 'with an incomplete configuration' do
    shared_examples 'fails to render with' do |message|
      it 'fails to render with a helpful error message', :aggregate_failures do
        expect(template.exit_code).not_to eq(0)
        expect(template.stderr).to include(message)
      end
    end

    context 'when anycable is enabled without live updates' do
      let(:default_values) do
        HelmTemplate.with_defaults(
          <<~YAML
            anycable:
              enabled: true
          YAML
        )
      end

      it_behaves_like 'fails to render with', 'anycable.enabled requires openproject.live_updates.enabled'
    end

    {
      'no secret' => ['auth', 'openproject.live_updates.auth.existingSecret is required'],
      'no broadcast URL' => ['broadcastUrl', 'openproject.live_updates.broadcastUrl is required']
    }.each do |missing, (key, message)|
      context "with an external anycable server and #{missing}" do
        let(:default_values) do
          live_updates = {
            'enabled' => true,
            'broadcastUrl' => 'http://anycable.other-namespace:2345/_broadcast',
            'auth' => { 'existingSecret' => 'external-secret' }
          }.except(key)

          HelmTemplate.with_defaults('openproject' => { 'live_updates' => live_updates })
        end

        it_behaves_like 'fails to render with', message
      end
    end
  end

  context 'with a network policy that restricts egress' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          anycable:
            enabled: true
            networkPolicy:
              enabled: true
              allowExternalEgress: false
          openproject:
            live_updates:
              enabled: true
        YAML
      )
    end

    it 'still allows the RPC calls to the web pods', :aggregate_failures do
      egress = template.dig('NetworkPolicy/optest-openproject-anycable', 'spec', 'egress')
      rpc_rule = egress.find { |rule| rule['to'] }

      expect(rpc_rule['ports']).to eq [{ 'port' => 8080 }]
      expect(rpc_rule['to'].first.dig('podSelector', 'matchLabels')).to include('openproject/process' => 'web')
    end
  end

  context 'with the chart network policies restricting egress' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          networkPolicy:
            enabled: true
            allowExternalEgress: false
          anycable:
            enabled: true
          openproject:
            live_updates:
              enabled: true
        YAML
      )
    end

    %w[optest-openproject-web optest-openproject-worker-default].each do |policy|
      it "allows #{policy} to broadcast to anycable" do
        egress = template.dig("NetworkPolicy/#{policy}", 'spec', 'egress')
        broadcast_rule = egress.find do |rule|
          rule['to']&.any? { |to| to.dig('podSelector', 'matchLabels', 'openproject/process') == 'anycable' }
        end

        expect(broadcast_rule&.dig('ports')).to eq [{ 'port' => 2345 }]
      end
    end
  end

  context 'with an external anycable server and only the bundled server secret set' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          anycable:
            auth:
              existingSecret: leftover-bundled-secret
          openproject:
            live_updates:
              enabled: true
              broadcastUrl: http://anycable.other-namespace:2345/_broadcast
        YAML
      )
    end

    it 'fails to render instead of using the bundled server secret', :aggregate_failures do
      expect(template.exit_code).not_to eq(0)
      expect(template.stderr).to include('openproject.live_updates.auth.existingSecret is required')
    end
  end

  context 'when rolling out anycable' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          anycable:
            enabled: true
          openproject:
            live_updates:
              enabled: true
        YAML
      )
    end

    it 'never runs two servers at once, as OpenProject broadcasts to only one of them' do
      expect(template.dig('Deployment/optest-openproject-anycable', 'spec', 'strategy', 'type')).to eq 'Recreate'
    end
  end

  context 'with the same pod annotation set globally and for anycable' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          podAnnotations:
            example.com/team: global
          anycable:
            enabled: true
            podAnnotations:
              example.com/team: anycable
          openproject:
            live_updates:
              enabled: true
        YAML
      )
    end

    # Psych keeps the last of duplicate keys, so count them in the rendered output
    it 'renders the annotation once, preferring the anycable one', :aggregate_failures do
      deployment = template.plain.split(/^---$/).find { |doc| doc.include?('name: optest-openproject-anycable') && doc.include?('kind: Deployment') }

      expect(deployment.scan(%r{^\s+example\.com/team:}).size).to eq 1
      expect(template.dig('Deployment/optest-openproject-anycable', 'spec', 'template', 'metadata', 'annotations', 'example.com/team')).to eq 'anycable'
    end
  end

  context 'with extraEnvVars overriding a chart set variable' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          anycable:
            enabled: true
            extraEnvVars:
              - name: ANYCABLE_BROADCAST_ADAPTER
                value: redisx
          openproject:
            live_updates:
              enabled: true
        YAML
      )
    end

    it 'renders each variable once, with the override', :aggregate_failures do
      adapters = env_of('optest-openproject-anycable').select { |e| e['name'] == 'ANYCABLE_BROADCAST_ADAPTER' }

      expect(adapters.size).to eq 1
      expect(adapters.first['value']).to eq 'redisx'
    end
  end
end
