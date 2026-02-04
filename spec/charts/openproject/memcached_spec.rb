# frozen_string_literal: true

require 'spec_helper'

describe 'memcached configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  subject { template.dig('Secret/optest-openproject-memcached', 'stringData') }

  context 'when memcached is bundled' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        openproject:
          cache:
            store: memcache
        memcached:
          bundled: true
      YAML
      )
    end

    it 'sets OPENPROJECT_CACHE__MEMCACHE__SERVER to release-based host:port' do
      expect(subject).to include('OPENPROJECT_CACHE__MEMCACHE__SERVER' => 'optest-memcached:11211')
    end
  end

  context 'when memcached.bundled is false with external connection details' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        memcached:
          bundled: false
          connection:
            host: cache.example.com
            port: 11211
      YAML
      )
    end

    it 'sets OPENPROJECT_CACHE__MEMCACHE__SERVER to the configured host:port' do
      expect(subject).to include('OPENPROJECT_CACHE__MEMCACHE__SERVER' => 'cache.example.com:11211')
    end
  end

  context 'when memcached.bundled is false without external connection details' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        memcached:
          bundled: false
      YAML
      )
    end

    it 'sets OPENPROJECT_CACHE__MEMCACHE__SERVER to empty string instead of ":"' do
      expect(subject).to include('OPENPROJECT_CACHE__MEMCACHE__SERVER' => '')
    end

    it 'does not produce an invalid ":" value that would cause YAML parse errors' do
      expect(subject['OPENPROJECT_CACHE__MEMCACHE__SERVER']).not_to eq(':')
    end
  end
end
