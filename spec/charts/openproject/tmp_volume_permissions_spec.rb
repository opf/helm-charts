# frozen_string_literal: true
require 'spec_helper'

describe 'tmp volume permission fix' do
  # resource => [main container, db-wait init container]
  let(:deployments) {
    {
      'Deployment/optest-openproject-web' => %w[openproject wait-for-db],
      'Deployment/optest-openproject-worker-default' => %w[openproject wait-for-db],
      'Deployment/optest-openproject-cron' => %w[cron wait-for-db],
      /optest-openproject-seeder/ => %w[seeder check-db-ready]
    }
  }

  context 'with tmp volumes enabled (default)' do
    let(:template) { HelmTemplate.new(HelmTemplate.with_defaults({})) }

    it 'adds a non-root prepare-tmpdir init container to every ruby pod', :aggregate_failures do
      deployments.each_key do |item|
        init = template.find_container(item, 'prepare-tmpdir', true)
        expect(init).not_to be_nil, "expected prepare-tmpdir init container in #{item}"

        security_context = init['securityContext']
        expect(security_context['runAsNonRoot']).to be(true)
        expect(security_context['runAsUser']).to eq(1000)
        expect(security_context['readOnlyRootFilesystem']).to be(true)

        expect(init['command'].last).to include('chmod 1777 /tmp/ruby')
        expect(init['volumeMounts'].map { |mount| mount['name'] }).to include('tmp')
      end
    end

    it 'orders prepare-tmpdir before the db-wait init container', :aggregate_failures do
      deployments.each do |item, (_main, db_init)|
        names = template.template_spec(item)['initContainers'].map { |c| c['name'] }
        expect(names.index('prepare-tmpdir')).to be < names.index(db_init)
      end
    end

    it 'points TMPDIR at the sticky-bit directory on the main and db-wait containers', :aggregate_failures do
      deployments.each do |item, (main, db_init)|
        expect(template.env_named(item, main, 'TMPDIR')&.dig('value')).to eq('/tmp/ruby')
        expect(template.env_named(item, db_init, 'TMPDIR', true)&.dig('value')).to eq('/tmp/ruby')
      end
    end
  end

  context 'when opting out via tmpVolumesPermissionFix=false' do
    let(:template) do
      HelmTemplate.new(HelmTemplate.with_defaults(<<~YAML))
        openproject:
          tmpVolumesPermissionFix: false
      YAML
    end

    it 'renders neither the init container nor TMPDIR', :aggregate_failures do
      deployments.each do |item, (main, _db_init)|
        expect(template.find_container(item, 'prepare-tmpdir', true)).to be_nil
        expect(template.env_named(item, main, 'TMPDIR')).to be_nil
      end
    end
  end

  context 'when tmp volumes are disabled' do
    let(:template) do
      HelmTemplate.new(HelmTemplate.with_defaults(<<~YAML))
        openproject:
          useTmpVolumes: false
      YAML
    end

    it 'renders neither the init container nor TMPDIR', :aggregate_failures do
      deployments.each do |item, (main, _db_init)|
        expect(template.find_container(item, 'prepare-tmpdir', true)).to be_nil
        expect(template.env_named(item, main, 'TMPDIR')).to be_nil
      end
    end
  end
end
