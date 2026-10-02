# frozen_string_literal: true
require 'spec_helper'

describe 'database password env vars' do
  let(:template) { HelmTemplate.new(default_values) }

  # docker/prod/migrate probes the database with psql, which only reads PGPASSWORD
  context 'with the default generated secret' do
    let(:default_values) { HelmTemplate.with_defaults('') }

    {
      'Deployment/optest-openproject-web' => 'openproject',
      'Deployment/optest-openproject-worker-default' => 'openproject',
      'Deployment/optest-openproject-cron' => 'cron'
    }.each do |item, container|
      it "sets PGPASSWORD alongside OPENPROJECT_DB_PASSWORD on #{item}", :aggregate_failures do
        db_password = template.env_named(item, container, 'OPENPROJECT_DB_PASSWORD')
        pg_password = template.env_named(item, container, 'PGPASSWORD')

        expect(pg_password).not_to be_nil
        expect(pg_password['valueFrom']).to eq(db_password['valueFrom'])
      end
    end

    it 'sets PGPASSWORD on the seeder job migrate and seeder containers', :aggregate_failures do
      job = 'Job/optest-openproject-seeder-1'

      expect(template.env_named(job, 'migrate', 'PGPASSWORD', true)).not_to be_nil
      expect(template.env_named(job, 'seeder', 'PGPASSWORD')).not_to be_nil
    end
  end

  context 'with an existing secret' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        postgresql:
          auth:
            existingSecret: my-db-secret
      YAML
      )
    end

    it 'reads PGPASSWORD from that secret' do
      pg_password = template.env_named('Deployment/optest-openproject-web', 'openproject', 'PGPASSWORD')

      expect(pg_password['valueFrom']['secretKeyRef']).to include('name' => 'my-db-secret', 'key' => 'password')
    end
  end

  context 'with an inline password' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        postgresql:
          auth:
            password: s3cr3t
      YAML
      )
    end

    it 'sets PGPASSWORD to that value' do
      pg_password = template.env_named('Deployment/optest-openproject-web', 'openproject', 'PGPASSWORD')

      expect(pg_password['value']).to eq('s3cr3t')
    end
  end
end
