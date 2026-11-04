# frozen_string_literal: true
require 'spec_helper'

describe 'egress TLS configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when configuring a root CA ConfigMap' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        egress:
          tls:
            rootCA:
              configMap: custom-root-ca
              fileName: rootCA.pem
      YAML
      )
    end

    it 'mounts the ConfigMap into the seeder container', :aggregate_failures do
      seeder = /optest-openproject-seeder/

      volume = template.find_volume(seeder, 'ca-pemstore')
      expect(volume).not_to be_nil
      expect(volume.dig('configMap', 'name')).to eq('custom-root-ca')

      mount = template.find_volume_mount(seeder, 'seeder', 'ca-pemstore')
      expect(mount).to include(
        'mountPath' => '/etc/ssl/certs/custom-ca.pem',
        'subPath' => 'rootCA.pem',
        'readOnly' => false
      )
    end

    it 'makes hocuspocus use the ConfigMap as its CA store', :aggregate_failures do
      hocuspocus = 'Deployment/optest-openproject-hocuspocus'

      mount = template.find_volume_mount(hocuspocus, 'hocuspocus', 'ca-pemstore')
      expect(mount).to include('mountPath' => '/etc/ssl/certs/custom-ca.pem', 'subPath' => 'rootCA.pem')

      expect(template.env_named(hocuspocus, 'hocuspocus', 'SSL_CERT_FILE')['value']).to eq '/etc/ssl/certs/custom-ca.pem'
      expect(template.env_named(hocuspocus, 'hocuspocus', 'NODE_EXTRA_CA_CERTS')['value']).to eq '/etc/ssl/certs/custom-ca.pem'
      expect(template.env_named(hocuspocus, 'hocuspocus', 'NODE_OPTIONS')['value']).to eq '--use-openssl-ca'
    end
  end

  describe 'replaceSystemStore' do
    let(:containers) do
      {
        'Deployment/optest-openproject-web' => 'openproject',
        'Deployment/optest-openproject-worker-default' => 'openproject',
        'Deployment/optest-openproject-cron' => 'cron',
        /optest-openproject-seeder/ => 'seeder',
        'Deployment/optest-openproject-hocuspocus' => 'hocuspocus',
        'Deployment/optest-openproject-anycable' => 'anycable'
      }
    end

    context 'when enabled with a root CA ConfigMap' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          cron:
            enabled: true
          anycable:
            enabled: true
          openproject:
            live_updates:
              enabled: true
          egress:
            tls:
              rootCA:
                configMap: ca-bundle
                fileName: ca-certificates.crt
                replaceSystemStore: true
        YAML
        )
      end

      it 'disables the hashed certificate directory in all containers', :aggregate_failures do
        containers.each do |item, container|
          expect(template.env_named(item, container, 'SSL_CERT_FILE')['value']).to eq '/etc/ssl/certs/custom-ca.pem'
          expect(template.env_named(item, container, 'SSL_CERT_DIR')['value']).to eq '/nonexistent'
        end
      end
    end

    context 'when not enabled with a root CA ConfigMap' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          cron:
            enabled: true
          anycable:
            enabled: true
          openproject:
            live_updates:
              enabled: true
          egress:
            tls:
              rootCA:
                configMap: ca-bundle
                fileName: ca-certificates.crt
        YAML
        )
      end

      it 'keeps the hashed certificate directory in all containers' do
        containers.each do |item, container|
          expect(template.env_named(item, container, 'SSL_CERT_DIR')).to be_nil
        end
      end
    end

    context 'when enabled without a root CA ConfigMap' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          egress:
            tls:
              rootCA:
                replaceSystemStore: true
        YAML
        )
      end

      it 'keeps the hashed certificate directory' do
        expect(template.env_named('Deployment/optest-openproject-web', 'openproject', 'SSL_CERT_DIR')).to be_nil
        expect(template.env_named('Deployment/optest-openproject-hocuspocus', 'hocuspocus', 'SSL_CERT_DIR')).to be_nil
      end
    end
  end

  context 'without a root CA ConfigMap' do
    let(:default_values) { {} }

    it 'does not set SSL_CERT_FILE for hocuspocus' do
      expect(template.env_named('Deployment/optest-openproject-hocuspocus', 'hocuspocus', 'SSL_CERT_FILE')).to be_nil
    end
  end
end
