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
  end
end
