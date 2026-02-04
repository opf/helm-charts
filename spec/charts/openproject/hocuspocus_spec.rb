# frozen_string_literal: true
require 'spec_helper'

describe 'configuring hocuspocus' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when hocuspocus is disabled while the global ingress is enabled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: true
          hocuspocus:
            enabled: false
        YAML
      )
    end

    it 'does not add the hocuspocus ingress', :aggregate_failures do
      paths = template.dig('Ingress/optest-openproject', 'spec', 'rules').first['http']['paths']

      expect(paths.size).to eq 1
      expect(paths.first['path']).to eq '/'
    end
  end

  context 'when hocuspocus is enabled (default) while the global ingress is enabled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: true
        YAML
      )
    end

    it 'adds the hocuspocus ingress', :aggregate_failures do
      paths = template.dig('Ingress/optest-openproject', 'spec', 'rules').first['http']['paths']

      expect(paths.size).to eq 2
      expect(paths.first['path']).to eq '/hocuspocus'
      expect(paths.last['path']).to eq '/'
    end
  end

  context 'when the global ingress is disabled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          ingress:
            enabled: false
        YAML
      )
    end

    it 'does not define an ingress' do
      ingress = template['Ingress/optest-openproject']

      expect(ingress).to be_nil
    end
  end

  context 'auth secrets' do
    context 'with nothing defined' do
      let(:default_values) do
        HelmTemplate.with_defaults(
          <<~YAML
            hocuspocus:
              enabled: true
          YAML
        )
      end

      it 'auto generates a secret' do
        secret = template.dig('Secret/hocuspocus-secret-auto-generated')

        expect(secret["stringData"]["secret"]).not_to be_empty
      end

      it 'sets the SECRET environment variable to the auto-generated secret in the hocuspocus deployment' do
        deployment = template.dig('Deployment/optest-openproject-hocuspocus')
        env = deployment.dig('spec', 'template', 'spec', 'containers').first['env']
        secret_env = env.find { |e| e['name'] == 'SECRET' }

        expect(secret_env).not_to be_nil
        expect(secret_env['valueFrom']['secretKeyRef']['name']).to eq 'hocuspocus-secret-auto-generated'
        expect(secret_env['valueFrom']['secretKeyRef']['key']).to eq 'secret'
      end

      it 'sets the SECRET environment variable to the auto-generated secret in the openproject-web deployment' do
        deployment = template.dig('Deployment/optest-openproject-web')
        env = deployment.dig('spec', 'template', 'spec', 'containers').first['env']
        secret_env = env.find { |e| e['name'] == 'OPENPROJECT_COLLABORATIVE__EDITING__HOCUSPOCUS__SECRET' }

        expect(secret_env).not_to be_nil
        expect(secret_env['valueFrom']['secretKeyRef']['name']).to eq 'hocuspocus-secret-auto-generated'
        expect(secret_env['valueFrom']['secretKeyRef']['key']).to eq 'secret'
      end
    end

    context 'with only the backend secret defined' do
      let(:default_values) do
        HelmTemplate.with_defaults(
          <<~YAML
            hocuspocus:
              enabled: true
              auth:
                existingSecret: hp-secret
          YAML
        )
      end

      it 'does not auto generate a secret' do
        secret = template.dig('Secret/hocuspocus-secret-auto-generated')

        expect(secret).to be_nil
      end

      it 'sets the SECRET environment variable to the named secret in the hocuspocus deployment' do
        deployment = template.dig('Deployment/optest-openproject-hocuspocus')
        env = deployment.dig('spec', 'template', 'spec', 'containers').first['env']
        secret_env = env.find { |e| e['name'] == 'SECRET' }

        expect(secret_env).not_to be_nil
        expect(secret_env['valueFrom']['secretKeyRef']['name']).to eq 'hp-secret'
        expect(secret_env['valueFrom']['secretKeyRef']['key']).to eq 'secret'
      end

      it 'sets the SECRET environment variable to the named secret in the openproject-web deployment' do
        deployment = template.dig('Deployment/optest-openproject-web')
        env = deployment.dig('spec', 'template', 'spec', 'containers').first['env']
        secret_env = env.find { |e| e['name'] == 'OPENPROJECT_COLLABORATIVE__EDITING__HOCUSPOCUS__SECRET' }

        expect(secret_env).not_to be_nil
        expect(secret_env['valueFrom']['secretKeyRef']['name']).to eq 'hp-secret'
        expect(secret_env['valueFrom']['secretKeyRef']['key']).to eq 'secret'
      end
    end

    context 'with only the frontend secret defined' do
      let(:default_values) do
        HelmTemplate.with_defaults(
          <<~YAML
            hocuspocus:
              enabled: false

            openproject:
              realtime_collaboration:
                hocuspocus:
                  auth:
                    existingSecret: rt-collab-secret
          YAML
        )
      end

      it 'does not auto generate a secret' do
        secret = template.dig('Secret/hocuspocus-secret-auto-generated')

        expect(secret).to be_nil
      end

      it 'does not create a hocuspocus deployment' do
        deployment = template.dig('Deployment/optest-openproject-hocuspocus')
        
        expect(deployment).to be_nil
      end

      it 'sets the SECRET environment variable to the named secret in the openproject-web deployment' do
        deployment = template.dig('Deployment/optest-openproject-web')
        env = deployment.dig('spec', 'template', 'spec', 'containers').first['env']
        secret_env = env.find { |e| e['name'] == 'OPENPROJECT_COLLABORATIVE__EDITING__HOCUSPOCUS__SECRET' }

        expect(secret_env).not_to be_nil
        expect(secret_env['valueFrom']['secretKeyRef']['name']).to eq 'rt-collab-secret'
        expect(secret_env['valueFrom']['secretKeyRef']['key']).to eq 'secret'
      end
    end
  end

  describe 'resources' do
    context 'when hocuspocus.resources is set' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          hocuspocus:
            enabled: true
            resources:
              requests:
                memory: "99Mi"
                cpu: "50m"
              limits:
                memory: "199Mi"
                cpu: "100m"
        YAML
        )
      end

      it 'uses hocuspocus.resources in the hocuspocus deployment (not .Values.resources)' do
        deployment = template.dig('Deployment/optest-openproject-hocuspocus')
        resources = deployment.dig('spec', 'template', 'spec', 'containers').first['resources']

        expect(resources).to include(
          'requests' => hash_including('memory' => '99Mi', 'cpu' => '50m'),
          'limits' => hash_including('memory' => '199Mi', 'cpu' => '100m')
        )
      end
    end

    context 'when hocuspocus.resourcesPreset is set (and resources not set)' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          hocuspocus:
            enabled: true
            resources: null
            resourcesPreset: small
        YAML
        )
      end

      it 'uses hocuspocus.resourcesPreset in the hocuspocus deployment' do
        deployment = template.dig('Deployment/optest-openproject-hocuspocus')
        resources = deployment.dig('spec', 'template', 'spec', 'containers').first['resources']

        # Bitnami common "small" preset: requests 512Mi, limits 768Mi
        expect(resources).not_to be_nil
        expect(resources.dig('requests', 'memory')).to eq('512Mi')
        expect(resources.dig('limits', 'memory')).to eq('768Mi')
      end
    end

    context 'when cron.resourcesPreset and hocuspocus.resourcesPreset are both set' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          hocuspocus:
            enabled: true
            resources: null
            resourcesPreset: small
          cron:
            enabled: true
            resourcesPreset: large
        YAML
        )
      end

      it 'uses hocuspocus.resourcesPreset (not cron.resourcesPreset) in the hocuspocus deployment' do
        deployment = template.dig('Deployment/optest-openproject-hocuspocus')
        resources = deployment.dig('spec', 'template', 'spec', 'containers').first['resources']

        # Should be "small" (768Mi limits), not "large" (3072Mi limits)
        expect(resources.dig('limits', 'memory')).to eq('768Mi')
        expect(resources.dig('limits', 'memory')).not_to eq('3072Mi')
      end
    end
  end
end
