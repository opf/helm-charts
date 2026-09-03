# frozen_string_literal: true

require 'spec_helper'

describe 'rustfs configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when rustfs is not bundled' do
    let(:default_values) { {} }

    it 'does not render the s3 secret', :aggregate_failures do
      expect(template.dig('Secret/optest-openproject-s3')).to be_nil
    end

    it 'does not render the rustfs credentials secret', :aggregate_failures do
      expect(template.dig('Secret/rustfs-credentials-auto-generated')).to be_nil
    end

    it 'does not render the bucket init job', :aggregate_failures do
      expect(template.dig('Job/optest-openproject-rustfs-init-bucket')).to be_nil
    end

    it 'does not render the s3 API ingress', :aggregate_failures do
      expect(template.dig('Ingress/optest-openproject-rustfs')).to be_nil
    end
  end

  context 'when rustfs is bundled without an s3Ingress host' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          rustfs:
            bundled: true
        YAML
      )
    end

    it 'fails to render with a helpful error message', :aggregate_failures do
      expect(template.exit_code).not_to eq(0)
      expect(template.stderr).to include('rustfs.s3Ingress.host is required')
    end
  end

  context 'when rustfs is bundled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          rustfs:
            bundled: true
            s3Ingress:
              host: s3.example.com
        YAML
      )
    end

    subject { template.dig('Secret/optest-openproject-s3', 'stringData') }

    it 'auto-configures the s3 secret to point at the public rustfs ingress host', :aggregate_failures do
      expect(subject).to include(
        "OPENPROJECT_ATTACHMENTS__STORAGE" => "fog",
        "OPENPROJECT_FOG_CREDENTIALS_PROVIDER" => "AWS",
        "OPENPROJECT_FOG_CREDENTIALS_ENDPOINT" => "https://s3.example.com",
        "OPENPROJECT_FOG_DIRECTORY" => "openproject",
        "OPENPROJECT_FOG_CREDENTIALS_REGION" => "us-east-1",
        "OPENPROJECT_FOG_CREDENTIALS_PATH__STYLE" => "true",
        "OPENPROJECT_FOG_CREDENTIALS_USE__IAM__PROFILE" => "false",
        "OPENPROJECT_DIRECT__UPLOADS" => "true"
      )
    end

    it 'does not include plain s3 access credentials in the generated secret', :aggregate_failures do
      expect(subject).not_to have_key('OPENPROJECT_FOG_CREDENTIALS_AWS__ACCESS__KEY__ID')
      expect(subject).not_to have_key('OPENPROJECT_FOG_CREDENTIALS_AWS__SECRET__ACCESS__KEY')
    end

    it 'auto-generates a shared credentials secret for rustfs and OpenProject', :aggregate_failures do
      creds = template.dig('Secret/rustfs-credentials-auto-generated', 'stringData')
      expect(creds.keys).to contain_exactly(
        'OPENPROJECT_FOG_CREDENTIALS_AWS__ACCESS__KEY__ID',
        'OPENPROJECT_FOG_CREDENTIALS_AWS__SECRET__ACCESS__KEY'
      )
    end

    it 'wires both the s3 secret and the generated credentials secret into the web deployment', :aggregate_failures do
      web_deployment = template.dig('Deployment/optest-openproject-web')
      env_from = web_deployment.dig('spec', 'template', 'spec', 'containers', 0, 'envFrom')

      names = env_from.map { |item| item.dig('secretRef', 'name') }
      expect(names).to include('optest-openproject-s3', 'rustfs-credentials-auto-generated')
    end

    it 'renders a post-install/upgrade hook job to create the bucket', :aggregate_failures do
      job = template.dig('Job/optest-openproject-rustfs-init-bucket')
      expect(job).not_to be_nil
      expect(job.dig('metadata', 'annotations', 'helm.sh/hook')).to eq('post-install,post-upgrade')

      container = job.dig('spec', 'template', 'spec', 'containers', 0)
      expect(container['image']).to include('rclone/rclone')
      expect(container.dig('envFrom', 0, 'secretRef', 'name')).to eq('rustfs-credentials-auto-generated')
      expect(container['args'].join).to include('force_path_style=true:openproject')
      # The init job talks to rustfs over the internal ClusterIP service, not the public ingress.
      expect(container['args'].join).to include('http://optest-rustfs-svc:9000')
    end

    it 'renders the bundled rustfs deployment in standalone mode', :aggregate_failures do
      deployment = template.dig('Deployment/optest-rustfs')
      expect(deployment).not_to be_nil
    end

    it 'enables CORS on the rustfs server so browser uploads/downloads are not blocked', :aggregate_failures do
      deployment = template.dig('Deployment/optest-rustfs')
      container = deployment.dig('spec', 'template', 'spec', 'containers', 0)
      cors_env = container['env'].find { |e| e['name'] == 'RUSTFS_CORS_ALLOWED_ORIGINS' }
      expect(cors_env['value']).to eq('*')
    end

    it 'hardens the rustfs pod/containers to match this chart\'s own security posture', :aggregate_failures do
      deployment = template.dig('Deployment/optest-rustfs')
      pod_security_context = deployment.dig('spec', 'template', 'spec', 'securityContext')
      expect(pod_security_context).to include('runAsUser', 'runAsGroup', 'fsGroup')
      expect(pod_security_context.values).to all(be > 0) # i.e. non-root

      deployment.dig('spec', 'template', 'spec', 'containers').each do |container|
        security_context = container['securityContext']
        expect(security_context).to include(
          'allowPrivilegeEscalation' => false,
          'readOnlyRootFilesystem' => true,
          'runAsNonRoot' => true,
          'seccompProfile' => { 'type' => 'RuntimeDefault' }
        )
        expect(security_context.dig('capabilities', 'drop')).to include('ALL')
      end
    end

    it 'renders a dedicated ingress targeting the rustfs S3 API (endpoint) port', :aggregate_failures do
      ingress = template.dig('Ingress/optest-openproject-rustfs')
      expect(ingress).not_to be_nil

      rule = ingress.dig('spec', 'rules', 0)
      expect(rule['host']).to eq('s3.example.com')

      backend = rule.dig('http', 'paths', 0, 'backend')
      expect(backend.dig('service', 'name')).to eq('optest-rustfs-svc')
      expect(backend.dig('service', 'port', 'name')).to eq('endpoint')
    end

    it 'does not enable the rustfs subchart\'s own (console) ingress', :aggregate_failures do
      # The bundled rustfs chart's ingress always targets its console port, not the S3 API, so it
      # must stay disabled to avoid a second, unusable ingress.
      expect(template.dig('Ingress/optest-rustfs')).to be_nil
    end

    it 'does not set TLS on the ingress when no tls secretName is configured', :aggregate_failures do
      ingress = template.dig('Ingress/optest-openproject-rustfs')
      expect(ingress.dig('spec', 'tls')).to be_nil
    end
  end

  context 'when rustfs is bundled with TLS configured' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          rustfs:
            bundled: true
            s3Ingress:
              host: s3.example.com
              tls:
                secretName: s3-tls
        YAML
      )
    end

    it 'sets TLS on the ingress and uses https in the presigned URL endpoint', :aggregate_failures do
      ingress = template.dig('Ingress/optest-openproject-rustfs')
      expect(ingress.dig('spec', 'tls')).to contain_exactly(
        { 'hosts' => ['s3.example.com'], 'secretName' => 's3-tls' }
      )

      subject = template.dig('Secret/optest-openproject-s3', 'stringData')
      expect(subject).to include("OPENPROJECT_FOG_CREDENTIALS_ENDPOINT" => "https://s3.example.com")
    end
  end

  context 'when rustfs is bundled with TLS left at its default (enabled, but no secretName set)' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          rustfs:
            bundled: true
            s3Ingress:
              host: s3.example.com
        YAML
      )
    end

    it 'does not add a tls stanza to the ingress', :aggregate_failures do
      ingress = template.dig('Ingress/optest-openproject-rustfs')
      expect(ingress.dig('spec', 'tls')).to be_nil
    end

    it 'it still uses https in the endpoint, as TLS may be terminated on another level', :aggregate_failures do
      subject = template.dig('Secret/optest-openproject-s3', 'stringData')
      expect(subject).to include("OPENPROJECT_FOG_CREDENTIALS_ENDPOINT" => "https://s3.example.com")
    end
  end

  context 'when rustfs is bundled with TLS disabled' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          rustfs:
            bundled: true
            s3Ingress:
              host: s3.example.com
              tls:
                enabled: false
        YAML
      )
    end

    it 'uses http in the presigned URL endpoint', :aggregate_failures do
      subject = template.dig('Secret/optest-openproject-s3', 'stringData')
      expect(subject).to include("OPENPROJECT_FOG_CREDENTIALS_ENDPOINT" => "http://s3.example.com")
    end
  end

  context 'when rustfs is bundled with a custom CORS allow-list' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          rustfs:
            bundled: true
            s3Ingress:
              host: s3.example.com
            extraEnv:
              - name: RUSTFS_CORS_ALLOWED_ORIGINS
                value: "https://openproject.example.com"
        YAML
      )
    end

    it 'overrides the default wildcard CORS origin', :aggregate_failures do
      deployment = template.dig('Deployment/optest-rustfs')
      container = deployment.dig('spec', 'template', 'spec', 'containers', 0)
      cors_env = container['env'].find { |e| e['name'] == 'RUSTFS_CORS_ALLOWED_ORIGINS' }
      expect(cors_env['value']).to eq('https://openproject.example.com')
    end
  end

  context 'when rustfs is bundled with a custom bucket name' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          rustfs:
            bundled: true
            bucketName: my-attachments
            s3Ingress:
              host: s3.example.com
        YAML
      )
    end

    it 'uses the custom bucket name for both OpenProject and the init job', :aggregate_failures do
      subject = template.dig('Secret/optest-openproject-s3', 'stringData')
      expect(subject).to include("OPENPROJECT_FOG_DIRECTORY" => "my-attachments")

      job = template.dig('Job/optest-openproject-rustfs-init-bucket')
      container = job.dig('spec', 'template', 'spec', 'containers', 0)
      expect(container['args'].join).to include('force_path_style=true:my-attachments')
    end
  end

  context 'when rustfs is bundled with a user-provided existing secret' do
    let(:default_values) do
      HelmTemplate.with_defaults(
        <<~YAML
          rustfs:
            bundled: true
            s3Ingress:
              host: s3.example.com
            secret:
              existingSecret: my-own-rustfs-secret
        YAML
      )
    end

    it 'does not auto-generate the credentials secret', :aggregate_failures do
      expect(template.dig('Secret/rustfs-credentials-auto-generated')).to be_nil
    end

    it 'wires the custom secret into the web deployment and bucket init job', :aggregate_failures do
      web_deployment = template.dig('Deployment/optest-openproject-web')
      env_from = web_deployment.dig('spec', 'template', 'spec', 'containers', 0, 'envFrom')
      names = env_from.map { |item| item.dig('secretRef', 'name') }
      expect(names).to include('my-own-rustfs-secret')

      job = template.dig('Job/optest-openproject-rustfs-init-bucket')
      container = job.dig('spec', 'template', 'spec', 'containers', 0)
      expect(container.dig('envFrom', 0, 'secretRef', 'name')).to eq('my-own-rustfs-secret')
    end
  end
end
