# frozen_string_literal: true
require 'spec_helper'

describe 'backup heartbeats' do
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
  let(:heartbeat_keys) do
    %w[BACKUP_MONITOR_HEARTBEAT_URL BACKUP_REPLICA_MONITOR_HEARTBEAT_URL BACKUP_VERIFICATION_MONITOR_HEARTBEAT_URL]
  end

  def secret
    template['Secret/optest-openproject-backup']['stringData']
  end

  context 'without heartbeat URLs' do
    let(:values) { base_values }

    it 'sets none' do
      expect(secret.keys & heartbeat_keys).to be_empty
    end
  end

  context 'with heartbeat URLs for all jobs' do
    let(:values) do
      base_values.deep_merge(
        'backup' => {
          'monitorHeartbeatUrl' => 'https://monitor.example.com/backup',
          'replica' => { 'monitorHeartbeatUrl' => 'https://monitor.example.com/replica' },
          'verification' => { 'monitorHeartbeatUrl' => 'https://monitor.example.com/verification' }
        }
      )
    end

    it 'passes each one to its job', :aggregate_failures do
      expect(secret['BACKUP_MONITOR_HEARTBEAT_URL']).to eq('https://monitor.example.com/backup')
      expect(secret['BACKUP_REPLICA_MONITOR_HEARTBEAT_URL']).to eq('https://monitor.example.com/replica')
      expect(secret['BACKUP_VERIFICATION_MONITOR_HEARTBEAT_URL']).to eq('https://monitor.example.com/verification')
    end

    context 'when replication is disabled' do
      let(:values) do
        super().deep_merge('backup' => { 'replica' => { 'enabled' => false } })
      end

      it 'omits the replication heartbeat' do
        expect(secret).not_to have_key('BACKUP_REPLICA_MONITOR_HEARTBEAT_URL')
      end
    end
  end
end
