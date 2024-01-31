# frozen_string_literal: true
require 'spec_helper'

describe 'oidc configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  let(:definitions) {
    {
      'Deployment/optest-openproject-web' => 'openproject',
      'Deployment/optest-openproject-worker' => 'openproject',
      /optest-openproject-seeder/ => 'seeder'
    }
  }

  context 'when setting extraOidcSealedSecret' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        openproject:
          oidc:
            extraOidcSealedSecret: openproject-oidc-secret-sealed
      YAML
      )
    end

    it 'adds that secret ref to relevant deployments', :aggregate_failures do
      definitions.each do |item, container|
        expect(template.secret_ref(item, container, 'openproject-oidc-secret-sealed'))
          .to be_a(Hash)
      end
    end
  end

  context 'when setting no imagePullSecrets' do
    let(:default_values) do
      {}
    end

    it 'adds the default secrets', :aggregate_failures do
      definitions.each do |item, container|
        expect(template.secret_ref(item, container, 'openproject-oidc-secret-sealed'))
          .to be_nil

        expect(template.env_from(item, container))
          .to include(
                { "secretRef" => { "name" => "optest-openproject-core" } },
                { "secretRef" => { "name" => "optest-openproject-memcached" } }
              )
      end
    end
  end
end
