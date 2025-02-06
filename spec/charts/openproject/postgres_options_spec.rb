# frozen_string_literal: true
require 'spec_helper'

describe 'PostgreSQL options' do
  let(:template) { HelmTemplate.new(default_values) }

  subject { template.dig('Secret/optest-openproject-core', 'stringData') }

  context 'when setting extraOidcSealedSecret' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        postgresql:
          options:
            pool: 5
            requireAuth: true
            channelBinding: require
            connectTimeout: 15
            clientEncoding: UTF8
            keepalives: 1
            keepalivesIdle: 30
            keepalivesInterval: 10
            keepalivesCount: 5
            replication: "on"
            gssencmode: disable
            sslmode: require
            sslcompression: 1
            sslMinProtocolVersion: TLSv1.2
            sslcert: /etc/ssl/certs/client-cert.pem
            sslkey: /etc/ssl/private/client-key.pem
            sslpassword: my-secure-password
            sslrootcert: /etc/ssl/certs/ca-cert.pem
            sslcrl: /etc/ssl/crl/server-crl.pem
      YAML
      )
    end

    it 'adds that secret ref to relevant deployments', :aggregate_failures do
      {
        "OPENPROJECT_DB_POOL" => 5,
        "OPENPROJECT_DB_REQUIRE_AUTH" => true,
        "OPENPROJECT_DB_CHANNEL_BINDING" => "require",
        "OPENPROJECT_DB_CONNECT_TIMEOUT" => 15,
        "OPENPROJECT_DB_CLIENT_ENCODING" => "UTF8",
        "OPENPROJECT_DB_KEEPALIVES" => 1,
        "OPENPROJECT_DB_KEEPALIVES_IDLE" => 30,
        "OPENPROJECT_DB_KEEPALIVES_INTERVAL" => 10,
        "OPENPROJECT_DB_KEEPALIVES_COUNT" => 5,
        "OPENPROJECT_DB_REPLICATION" => true,
        "OPENPROJECT_DB_GSSENCMODE" => "disable",
        "OPENPROJECT_DB_SSLMODE" => "require",
        "OPENPROJECT_DB_SSLCOMPRESSION" => 1,
        "OPENPROJECT_DB_SSLCERT" => "/etc/ssl/certs/client-cert.pem",
        "OPENPROJECT_DB_SSLKEY" => "/etc/ssl/private/client-key.pem",
        "OPENPROJECT_DB_SSLPASSWORD" => "my-secure-password",
        "OPENPROJECT_DB_SSLROOTCERT" => "/etc/ssl/certs/ca-cert.pem",
        "OPENPROJECT_DB_SSLCRL" => "/etc/ssl/crl/server-crl.pem",
        "OPENPROJECT_DB_SSL_MIN_PROTOCOL_VERSION" => "TLSv1.2",
      }.each do |key, val|
        expect(subject[key]).to eq(val)
      end
    end
  end

  context 'when setting no imagePullSecrets' do
    let(:default_values) do
      {}
    end

    it 'adds the default secrets', :aggregate_failures do
      db_keys = subject.keys.select { |k| k.start_with?('OPENPROJECT_DB_') }
      expect(db_keys).to be_empty
    end
  end
end
