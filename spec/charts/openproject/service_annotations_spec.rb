# frozen_string_literal: true
require 'spec_helper'

describe 'openproject service annotations' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'when only commonAnnotations are set' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonAnnotations:
          example.com/team: platform
      YAML
      )
    end

    it 'adds commonAnnotations to the service' do
      annotations = template.dig('Service/optest-openproject', 'metadata', 'annotations')
      expect(annotations['example.com/team']).to eq('platform')
    end
  end

  context 'when only service.annotations are set' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        service:
          annotations:
            service.beta.kubernetes.io/aws-load-balancer-type: nlb
      YAML
      )
    end

    it 'adds service-specific annotations to the service' do
      annotations = template.dig('Service/optest-openproject', 'metadata', 'annotations')
      expect(annotations['service.beta.kubernetes.io/aws-load-balancer-type']).to eq('nlb')
    end
  end

  context 'when both service.annotations and commonAnnotations are set' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonAnnotations:
          example.com/team: platform
        service:
          annotations:
            service.beta.kubernetes.io/aws-load-balancer-type: nlb
      YAML
      )
    end

    it 'merges both annotation sets on the service' do
      annotations = template.dig('Service/optest-openproject', 'metadata', 'annotations')
      expect(annotations['example.com/team']).to eq('platform')
      expect(annotations['service.beta.kubernetes.io/aws-load-balancer-type']).to eq('nlb')
    end
  end

  context 'when no annotations are set' do
    let(:default_values) { HelmTemplate.with_defaults({}) }

    it 'does not add an annotations field to the service' do
      annotations = template.dig('Service/optest-openproject', 'metadata', 'annotations')
      expect(annotations).to be_nil
    end
  end
end
