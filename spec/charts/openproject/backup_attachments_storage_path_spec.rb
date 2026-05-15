# frozen_string_literal: true
require 'spec_helper'

describe 'backup attachments storage path' do
  let(:template) { HelmTemplate.new(values) }
  let(:base_values) do
    {
      'backup' => {
        'enabled' => true,
        's3' => {
          'endpoint' => 'backup-s3:9000',
          'bucket' => 'backup',
          'auth' => { 'accessKeyId' => 'access', 'secretAccessKey' => 'secret' }
        }
      }
    }
  end

  let(:pod_spec) do
    template.spec('CronJob/optest-openproject-backup').dig('jobTemplate', 'spec', 'template', 'spec')
  end
  let(:backup_container) { pod_spec['containers'].find { |c| c['name'] == 'backup' } }
  let(:prepare_container) { pod_spec['initContainers'].find { |c| c['name'] == 'prepare-assets' } }

  def sub_path(mount_path)
    backup_container['volumeMounts'].find { |m| m['mountPath'] == mount_path }&.dig('subPath')
  end

  shared_examples 'backs up attachments from' do |relative_path|
    it 'mounts attachment and custom_style from that path', :aggregate_failures do
      expect(sub_path('/backup/attachment')).to eq([relative_path, 'attachment'].compact.join('/'))
      expect(sub_path('/backup/custom_style')).to eq([relative_path, 'custom_style'].compact.join('/'))
      expect(prepare_container['command']).to eq(
        ['mkdir', '-p', *%w[attachment custom_style].map { |dir| ['/assets', relative_path, dir].compact.join('/') }]
      )
    end
  end

  context 'with the default storage path' do
    let(:values) { base_values }

    include_examples 'backs up attachments from', 'files'
  end

  context 'when OPENPROJECT_ATTACHMENTS__STORAGE__PATH is overridden in environment' do
    let(:values) do
      base_values.merge('environment' => { 'OPENPROJECT_ATTACHMENTS__STORAGE__PATH' => '/var/openproject/assets/custom/dir/' })
    end

    include_examples 'backs up attachments from', 'custom/dir'
  end

  context 'when backup.attachmentsStoragePath is set' do
    let(:values) do
      base_values.deep_merge(
        'environment' => { 'OPENPROJECT_ATTACHMENTS__STORAGE__PATH' => '/var/openproject/assets/ignored' },
        'backup' => { 'attachmentsStoragePath' => '/var/openproject/assets/explicit' }
      )
    end

    include_examples 'backs up attachments from', 'explicit'
  end

  context 'when the storage path is the root of the assets volume' do
    let(:values) { base_values.deep_merge('backup' => { 'attachmentsStoragePath' => '/var/openproject/assets' }) }

    include_examples 'backs up attachments from', nil
  end

  context 'when the storage path is not on the assets volume' do
    let(:values) { base_values.deep_merge('backup' => { 'attachmentsStoragePath' => '/var/openproject/assets2/files' }) }

    it 'fails with a helpful message', :aggregate_failures do
      expect(template.exit_code).not_to eq(0)
      expect(template.stderr).to include('is not on the assets volume')
    end
  end

  context 'when attachments are stored in S3' do
    let(:values) do
      base_values.merge(
        'environment' => { 'OPENPROJECT_ATTACHMENTS__STORAGE__PATH' => '/somewhere/else' },
        's3' => { 'enabled' => true, 'auth' => { 'accessKeyId' => 'a', 'secretAccessKey' => 'b' }, 'bucketName' => 'op' }
      )
    end

    it 'ignores the local storage path and does not mount the assets volume', :aggregate_failures do
      expect(template.exit_code).to eq(0)
      expect(sub_path('/backup/attachment')).to be_nil
      expect(pod_spec['initContainers'].map { |c| c['name'] }).to eq(['db-dump'])
    end
  end
end
