# frozen_string_literal: true
require 'spec_helper'

describe 'backup pod security' do
  let(:template) { HelmTemplate.new(values) }
  let(:base_values) do
    {
      'backup' => {
        'enabled' => true,
        's3' => {
          'endpoint' => 'backup-s3:9000',
          'bucket' => 'backup',
          'auth' => { 'accessKeyId' => 'access', 'secretAccessKey' => 'secret' }
        },
        'replica' => {
          'enabled' => true,
          's3' => {
            'endpoint' => 'replica-s3:9000',
            'bucket' => 'replica',
            'auth' => { 'accessKeyId' => 'access', 'secretAccessKey' => 'secret' }
          }
        }
      }
    }
  end
  let(:s3_values) do
    { 's3' => { 'enabled' => true, 'auth' => { 'accessKeyId' => 'a', 'secretAccessKey' => 'b' }, 'bucketName' => 'op' } }
  end

  cronjobs = %w[backup backup-replica backup-verification]

  def pod_spec(cronjob)
    template.spec("CronJob/optest-openproject-#{cronjob}").dig('jobTemplate', 'spec', 'template', 'spec')
  end

  def all_containers(cronjob)
    pod_spec(cronjob).values_at('initContainers', 'containers').compact.flatten
  end

  def backup_container
    pod_spec('backup')['containers'].find { |c| c['name'] == 'backup' }
  end

  def secret_value(key)
    template['Secret/optest-openproject-backup']['stringData'][key]
  end

  shared_examples 'restricted pods' do
    it 'runs all backup containers with the chart\'s restricted security context', :aggregate_failures do
      cronjobs.each do |cronjob|
        expect(pod_spec(cronjob)['securityContext']).to include('fsGroup' => 1000)
        all_containers(cronjob).each do |container|
          expect(container['securityContext']).to include(
            'runAsNonRoot' => true, 'allowPrivilegeEscalation' => false,
            'capabilities' => { 'drop' => ['ALL'] }, 'seccompProfile' => { 'type' => 'RuntimeDefault' }
          ), "#{cronjob}/#{container['name']}"
          expect(container['securityContext']).not_to have_key('privileged')
        end
      end
    end
  end

  context 'with attachments on the assets volume' do
    let(:values) { base_values }

    include_examples 'restricted pods'

    it 'snapshots the assets volume' do
      expect(secret_value('ATTACHMENTS_STORAGE')).to eq('local')
    end
  end

  context 'with attachments in S3 and no volume for them' do
    let(:values) { base_values.merge(s3_values) }

    it 'mounts the bucket via FUSE in a privileged backup container', :aggregate_failures do
      expect(backup_container['securityContext']).to eq('privileged' => true)
      expect(secret_value('ATTACHMENTS_STORAGE')).to eq('s3')
      expect(backup_container['envFrom'].map { |e| e['secretRef']['name'] }).to include('optest-openproject-s3')
    end

    it 'keeps all other containers restricted', :aggregate_failures do
      (all_containers('backup') - [backup_container] + all_containers('backup-replica') + all_containers('backup-verification'))
        .each { |container| expect(container['securityContext']).to include('runAsNonRoot' => true) }
    end
  end

  context 'with attachments in S3 provided as a volume' do
    let(:values) { base_values.merge(s3_values).deep_merge('backup' => { 's3Attachments' => { 'existingClaim' => 'op-bucket' } }) }

    include_examples 'restricted pods'

    it 'snapshots the uploads directory of the volume', :aggregate_failures do
      expect(secret_value('ATTACHMENTS_STORAGE')).to eq('local')
      expect(pod_spec('backup')['volumes']).to include('name' => 'data', 'persistentVolumeClaim' => { 'claimName' => 'op-bucket' })
      mounts = backup_container['volumeMounts'].to_h { |m| [m['mountPath'], m['subPath']] }
      expect(mounts).to include('/mnt/backup/attachment' => 'uploads/attachment', '/mnt/backup/custom_style' => 'uploads/custom_style')
      expect(backup_container['envFrom'].map { |e| e['secretRef']['name'] }).not_to include('optest-openproject-s3')
    end

    context 'when the volume is the uploads prefix itself' do
      let(:values) do
        base_values.merge(s3_values).deep_merge('backup' => { 's3Attachments' => { 'existingClaim' => 'op-bucket', 'path' => '' } })
      end

      it 'snapshots the root of the volume' do
        mounts = backup_container['volumeMounts'].to_h { |m| [m['mountPath'], m['subPath']] }
        expect(mounts).to include('/mnt/backup/attachment' => 'attachment', '/mnt/backup/custom_style' => 'custom_style')
      end
    end
  end

  context 'with attachments in the bundled RustFS' do
    let(:values) { base_values.merge('rustfs' => { 'bundled' => true, 'ingress' => { 'host' => 's3.example.com' } }) }

    def env(name)
      backup_container['env'].find { |e| e['name'] == name }
    end

    it 'mounts the bucket via FUSE from the in-cluster RustFS service', :aggregate_failures do
      expect(backup_container['securityContext']).to eq('privileged' => true)
      expect(secret_value('ATTACHMENTS_STORAGE')).to eq('s3')
      expect(env('OPENPROJECT_FOG_CREDENTIALS_ENDPOINT')['value']).to eq('http://optest-openproject-rustfs-svc:9000')
      expect(env('OPENPROJECT_FOG_CREDENTIALS_AWS__ACCESS__KEY__ID').dig('valueFrom', 'secretKeyRef'))
        .to eq('name' => 'rustfs-credentials-auto-generated', 'key' => 'RUSTFS_ACCESS_KEY')
      expect(pod_spec('backup')['volumes'].map { |v| v['name'] }).not_to include('data')
    end

    context 'when the bucket is provided as a volume' do
      let(:values) do
        base_values.merge('rustfs' => { 'bundled' => true, 'ingress' => { 'host' => 's3.example.com' } })
                   .deep_merge('backup' => { 's3Attachments' => { 'existingClaim' => 'op-bucket' } })
      end

      include_examples 'restricted pods'
    end
  end

  context 'with a service account for the backups' do
    let(:values) { base_values.deep_merge('backup' => { 'serviceAccountName' => 'backup-privileged' }) }

    it 'uses it for all backup pods', :aggregate_failures do
      cronjobs.each { |cronjob| expect(pod_spec(cronjob)['serviceAccountName']).to eq('backup-privileged') }
    end
  end
end
