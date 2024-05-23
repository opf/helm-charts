# frozen_string_literal: true
require 'spec_helper'

describe 'extraVolumes and extraVolumeMounts configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  let(:definitions) {
    {
      'Deployment/optest-openproject-web' => 'openproject',
      'Deployment/optest-openproject-worker-default' => 'openproject',
      /optest-openproject-seeder/ => 'seeder'
    }
  }

  context 'when setting extraVolumes ' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        extraVolumes:
          - name: "trusted-cert-secret-volume"
            secret:
              secretName: "my-certificates-ca-tls"
              items:
                - key: "ca.crt"
                  path: "ca-certificates.crt"
        extraVolumeMounts:
          - name: "trusted-cert-secret-volume"
            mountPath: "/etc/ssl/certs/ca-certificates.crt"
            subPath: "ca-certificates.crt"
      YAML
      )
    end

    it 'Populates those volume definitions for all deployments', :aggregate_failures do
      definitions.each do |item, container_ref|
        volume = template.find_volume(item, "trusted-cert-secret-volume")
        expect(volume).not_to be_nil
        expect(volume['secret']['secretName']).to eq("my-certificates-ca-tls")
        expect(volume['secret']['items'][0]['key']).to eq("ca.crt")
        expect(volume['secret']['items'][0]['path']).to eq("ca-certificates.crt")

        container = template.find_container(item, container_ref)
        mount = container.dig('volumeMounts').detect { |mount| mount["name"] == "trusted-cert-secret-volume" }
        expect(mount).not_to be_nil
      end
    end
  end

  context 'when setting no imagePullSecrets' do
    let(:default_values) do
      {}
    end

    it 'Populates annotations for all deployments', :aggregate_failures do
      definitions.each do |item, container_ref|
        volume = template.find_volume(item, "trusted-cert-secret-volume")
        expect(volume).to be_nil

        container = template.find_container(item, container_ref)
        mount = container.dig('volumeMounts').detect { |mount| mount["name"] == "trusted-cert-secret-volume" }
        expect(mount).to be_nil

      end
    end
  end
end
