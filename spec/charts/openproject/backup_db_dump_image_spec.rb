# frozen_string_literal: true
require 'spec_helper'

describe 'backup database dump image' do
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
  let(:external_database) do
    {
      'postgresql' => {
        'bundled' => false,
        'connection' => { 'host' => 'db.example.com', 'port' => 5432 },
        'auth' => { 'password' => 'secret' }
      }
    }
  end

  def db_dump_image
    template.spec('CronJob/optest-openproject-backup')
            .dig('jobTemplate', 'spec', 'template', 'spec', 'initContainers')
            .find { |container| container['name'] == 'db-dump' }['image']
  end

  context 'with the bundled PostgreSQL' do
    let(:values) { base_values }

    it 'uses pg_dump of the bundled server\'s major version' do
      major = YAML.load_file(File.join(__dir__, '../../../charts/openproject/values.yaml'))
                  .dig('postgresql', 'image', 'tag').to_s[/\A\d+/]

      expect(db_dump_image).to eq("docker.io/postgres:#{major}-alpine")
    end

    context 'with another PostgreSQL image' do
      let(:values) { base_values.merge('postgresql' => { 'image' => { 'tag' => '16.2.0-debian-12-r1' } }) }

      it 'follows its major version' do
        expect(db_dump_image).to eq('docker.io/postgres:16-alpine')
      end
    end

    context 'with an image tag the major version cannot be read from' do
      let(:values) { base_values.merge('postgresql' => { 'image' => { 'tag' => 'latest' } }) }

      it 'fails asking for the dump image tag', :aggregate_failures do
        expect(template.exit_code).not_to eq(0)
        expect(template.stderr).to include('Set backup.dbDump.image.tag')
      end
    end
  end

  context 'with an external database' do
    let(:values) { base_values.merge(external_database) }

    it 'fails asking for the dump image tag matching the server', :aggregate_failures do
      expect(template.exit_code).not_to eq(0)
      expect(template.stderr).to include('set backup.dbDump.image.tag to a postgres image tag matching the major version')
    end

    context 'when the dump image tag is set' do
      let(:values) { base_values.merge(external_database).deep_merge('backup' => { 'dbDump' => { 'image' => { 'tag' => '17-alpine' } } }) }

      it 'uses it' do
        expect(db_dump_image).to eq('docker.io/postgres:17-alpine')
      end
    end
  end
end
