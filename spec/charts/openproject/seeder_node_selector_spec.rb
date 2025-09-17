# frozen_string_literal: true
require 'spec_helper'

describe 'seeder nodeSelector configuration' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when setting global nodeSelector only' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector:
          node-type: general
          workload: default
      YAML
      )
    end

    it 'applies global nodeSelector to seeder job', :aggregate_failures do
      seeder_spec = template.template_spec('Job/optest-openproject-seeder-1')
      expect(seeder_spec['nodeSelector']).to include('node-type' => 'general')
      expect(seeder_spec['nodeSelector']).to include('workload' => 'default')
    end
  end

  context 'when setting seeder-specific nodeSelector' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector:
          node-type: general
          workload: default
        seeder:
          nodeSelector:
            node-type: seeder
            workload: on-demand
            zone: us-west-1c
      YAML
      )
    end

    it 'applies seeder-specific nodeSelector to seeder job', :aggregate_failures do
      seeder_spec = template.template_spec('Job/optest-openproject-seeder-1')
      expect(seeder_spec['nodeSelector']).to include('node-type' => 'seeder')
      expect(seeder_spec['nodeSelector']).to include('workload' => 'on-demand')
      expect(seeder_spec['nodeSelector']).to include('zone' => 'us-west-1c')
      expect(seeder_spec['nodeSelector']).not_to include('node-type' => 'general')
    end
  end

  context 'when setting empty seeder nodeSelector' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        nodeSelector:
          node-type: general
          workload: default
        seeder:
          nodeSelector: {}
      YAML
      )
    end

    it 'falls back to global nodeSelector on seeder job', :aggregate_failures do
      seeder_spec = template.template_spec('Job/optest-openproject-seeder-1')
      expect(seeder_spec['nodeSelector']).to include('node-type' => 'general')
      expect(seeder_spec['nodeSelector']).to include('workload' => 'default')
    end
  end

  context 'when setting no nodeSelector configuration' do
    let(:default_values) do
      {}
    end

    it 'does not set nodeSelector on seeder job', :aggregate_failures do
      seeder_spec = template.template_spec('Job/optest-openproject-seeder-1')
      expect(seeder_spec['nodeSelector']).to be_nil
    end
  end
end
