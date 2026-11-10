# frozen_string_literal: true
require 'spec_helper'

describe 'bundled PostgreSQL' do
  let(:values) { {} }
  let(:template) { HelmTemplate.new(values) }
  let(:statefulset) { template['StatefulSet/optest-openproject-database'] }
  let(:pod) { statefulset.dig('spec', 'template', 'spec') }
  let(:container) { pod['containers'].first }

  it 'uses the upstream vector image, a separate PVC, and non-root database user' do
    expect(container['image']).to eq('docker.io/pgvector/pgvector:pg18-bookworm')
    expect(container.dig('securityContext', 'runAsUser')).to eq(999)
    expect(pod.dig('securityContext', 'fsGroup')).to eq(999)
    expect(container['volumeMounts']).to include(hash_including('mountPath' => '/var/lib/postgresql'))
    expect(statefulset.dig('spec', 'volumeClaimTemplates', 0, 'metadata', 'name')).to eq('data')
    expect(template['StatefulSet/optest-postgresql']).to be_nil
  end

  it 'initializes a non-superuser application role and vector only on first database initialization' do
    script = template['ConfigMap/optest-openproject-database-init'].dig('data', '01-openproject.sh')
    expect(script).to include('CREATE ROLE :"app_user" LOGIN', 'CREATE EXTENSION vector;', 'ON_ERROR_STOP=1')
    expect(script).not_to include('SUPERUSER')
  end

  it 'connects the application to the new service using the same credential secret as PostgreSQL' do
    core = template['Secret/optest-openproject-core']['stringData']
    expect(core['DATABASE_HOST']).to eq('optest-openproject-database.default.svc.cluster.local')
    expect(core['DATABASE_URL']).to eq('postgresql://openproject@optest-openproject-database:5432/openproject')
    db_password = template.env_named('StatefulSet/optest-openproject-database', 'postgresql', 'OPENPROJECT_DB_PASSWORD')
    app_password = template.env_named('Deployment/optest-openproject-web', 'openproject', 'PGPASSWORD')
    expect(app_password['valueFrom']).to eq(db_password['valueFrom'])
    secret = template['Secret/optest-openproject-database-auto-generated']
    expect(secret.dig('metadata', 'annotations', 'helm.sh/resource-policy')).to eq('keep')
    expect(secret['stringData'].keys).to contain_exactly('postgres-password', 'password')
  end

  it 'keeps a distinct database service name for long release names' do
    long_template = HelmTemplate.new({}, 'openproject', 'a' * 53)
    services = long_template.resources_by_kind('Service').values.map { |service| service.dig('metadata', 'name') }
    database = services.find { |name| name.end_with?('-database') }
    expect(database.length).to be <= 63
    expect(services.count(database)).to eq(1)
  end

  context 'with resource presets disabled' do
    let(:values) { { 'postgresql' => { 'resourcesPreset' => 'none' } } }

    it 'renders without resource requirements' do
      expect(template.exit_code).to eq(0)
      expect(container).not_to have_key('resources')
    end
  end

  context 'with the global image pull policy' do
    let(:values) { { 'image' => { 'imagePullPolicy' => 'Always' }, 'postgresql' => { 'image' => { 'pullPolicy' => '' } } } }

    it 'inherits the application image pull policy when unset' do
      expect(container['imagePullPolicy']).to eq('Always')
    end
  end

  context 'with existing credentials and storage' do
    let(:values) do
      { 'postgresql' => {
        'auth' => { 'existingSecret' => 'db-credentials', 'secretKeys' => { 'adminPasswordKey' => 'admin', 'userPasswordKey' => 'app' } },
        'persistence' => { 'existingClaim' => 'restored-pg18' }
      } }
    end

    it 'uses references without rendering a replacement Secret or PVC template' do
      expect(template['Secret/optest-openproject-database-auto-generated']).to be_nil
      expect(statefulset['spec']).not_to have_key('volumeClaimTemplates')
      expect(pod['volumes']).to include('name' => 'data', 'persistentVolumeClaim' => { 'claimName' => 'restored-pg18' })
      expect(template.env_named('StatefulSet/optest-openproject-database', 'postgresql', 'POSTGRES_PASSWORD').dig('valueFrom', 'secretKeyRef')).to eq('name' => 'db-credentials', 'key' => 'admin')
    end
  end

  context 'with an external database' do
    let(:values) { { 'postgresql' => { 'bundled' => false, 'connection' => { 'host' => 'db.example', 'port' => 5433 }, 'auth' => { 'existingSecret' => 'external-db' } } } }

    it 'does not deploy database resources and keeps the external connection path' do
      expect(statefulset).to be_nil
      expect(template['Secret/optest-openproject-database-auto-generated']).to be_nil
      expect(template['ConfigMap/optest-openproject-database-init']).to be_nil
      expect(template['Secret/optest-openproject-core'].dig('stringData', 'DATABASE_URL')).to eq('postgresql://openproject@db.example:5433/openproject')
    end
  end

  context 'with restricted egress' do
    let(:values) { { 'networkPolicy' => { 'enabled' => true, 'allowExternalEgress' => false } } }

    it 'allows application traffic to the bundled database' do
      expect(template['NetworkPolicy/optest-openproject-database']).not_to be_nil
      %w[web worker-default cron seeder].each do |process|
        rules = template["NetworkPolicy/optest-openproject-#{process}"].dig('spec', 'egress')
        expect(rules).to include(hash_including('ports' => [{ 'port' => 5432, 'protocol' => 'TCP' }]))
      end
    end
  end

  context 'with PostgreSQL 17 selected for a new cluster' do
    let(:values) { { 'postgresql' => { 'image' => { 'tag' => 'pg17-bookworm' }, 'dataDirectory' => '/var/lib/postgresql/17/docker' } } }

    it 'uses the explicitly selected image and data location' do
      expect(container['image']).to end_with(':pg17-bookworm')
      expect(template.env_named('StatefulSet/optest-openproject-database', 'postgresql', 'PGDATA')['value']).to eq('/var/lib/postgresql/17/docker')
    end
  end
end
