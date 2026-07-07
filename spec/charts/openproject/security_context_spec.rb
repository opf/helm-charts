# frozen_string_literal: true
require 'spec_helper'

describe 'security context' do
  let(:template) { HelmTemplate.new(HelmTemplate.with_defaults({})) }

  let(:pod_spec_paths) do
    {
      'Pod' => %w[spec],
      'Deployment' => %w[spec template spec],
      'StatefulSet' => %w[spec template spec],
      'DaemonSet' => %w[spec template spec],
      'ReplicaSet' => %w[spec template spec],
      'Job' => %w[spec template spec],
      'CronJob' => %w[spec jobTemplate spec template spec]
    }
  end

  let(:allowed_seccomp_types) { %w[RuntimeDefault Localhost] }
  let(:allowed_selinux_types) { [nil, '', 'container_t', 'container_init_t', 'container_kvm_t', 'container_engine_t'] }
  let(:restricted_volume_types) do
    %w[
      configMap
      csi
      downwardAPI
      emptyDir
      ephemeral
      persistentVolumeClaim
      projected
      secret
    ]
  end

  def rendered_pod_specs
    pod_spec_paths.flat_map do |kind, path|
      template.resources_by_kind(kind).filter_map do |resource_name, resource|
        pod_spec = resource.dig(*path)
        [resource_name, pod_spec] if pod_spec
      end
    end
  end

  def containers_for(pod_spec)
    pod_spec.fetch('containers', []) + pod_spec.fetch('initContainers', [])
  end

  def effective_security_context(pod_spec, container)
    pod_spec.fetch('securityContext', {}).merge(container.fetch('securityContext', {}))
  end

  it 'renders pod specs and containers to check' do
    expect(rendered_pod_specs).not_to be_empty

    rendered_pod_specs.each do |resource_name, pod_spec|
      expect(containers_for(pod_spec)).not_to be_empty, "expected #{resource_name} to render at least one container"
    end
  end

  it 'sets the restricted security context on every container', :aggregate_failures do
    rendered_pod_specs.each do |resource_name, pod_spec|
      containers_for(pod_spec).each do |container|
        security_context = effective_security_context(pod_spec, container)
        container_name = "#{resource_name}/#{container['name']}"

        expect(security_context['allowPrivilegeEscalation']).to be(false), container_name
        expect(security_context['runAsNonRoot']).to be(true), container_name
        expect(security_context['runAsUser']).not_to be_nil, container_name
        expect(security_context['runAsUser']).not_to eq(0), container_name
        expect(allowed_seccomp_types).to include(security_context.dig('seccompProfile', 'type')), container_name
        expect(security_context.dig('capabilities', 'drop')).to include('ALL'), container_name
        expect(Array(security_context.dig('capabilities', 'add'))).to all(eq('NET_BIND_SERVICE')), container_name
      end
    end
  end

  it 'does not render baseline-prohibited pod and container settings', :aggregate_failures do
    rendered_pod_specs.each do |resource_name, pod_spec|
      expect(pod_spec['hostNetwork']).not_to be(true), resource_name
      expect(pod_spec['hostPID']).not_to be(true), resource_name
      expect(pod_spec['hostIPC']).not_to be(true), resource_name
      expect(allowed_selinux_types).to include(pod_spec.dig('securityContext', 'seLinuxOptions', 'type')), resource_name
      expect(pod_spec.dig('securityContext', 'seLinuxOptions', 'user')).to be_nil, resource_name
      expect(pod_spec.dig('securityContext', 'seLinuxOptions', 'role')).to be_nil, resource_name

      containers_for(pod_spec).each do |container|
        container_name = "#{resource_name}/#{container['name']}"

        expect(container.dig('securityContext', 'privileged')).not_to be(true), container_name
        expect(container.dig('securityContext', 'procMount')).to satisfy { |value| value.nil? || value == 'Default' }, container_name
        expect(allowed_selinux_types).to include(container.dig('securityContext', 'seLinuxOptions', 'type')), container_name
        expect(container.dig('securityContext', 'seLinuxOptions', 'user')).to be_nil, container_name
        expect(container.dig('securityContext', 'seLinuxOptions', 'role')).to be_nil, container_name

        container.fetch('ports', []).each do |port|
          expect(port['hostPort']).to satisfy { |value| value.nil? || value.zero? }, container_name
        end
      end
    end
  end

  it 'uses only restricted volume types', :aggregate_failures do
    rendered_pod_specs.each do |resource_name, pod_spec|
      pod_spec.fetch('volumes', []).each do |volume|
        volume_types = volume.reject { |key, value| key == 'name' || value.nil? }.keys

        expect(volume_types).not_to include('hostPath'), "#{resource_name}/#{volume['name']}"
        expect(volume_types).not_to be_empty, "#{resource_name}/#{volume['name']}"
        expect(volume_types - restricted_volume_types).to be_empty, "#{resource_name}/#{volume['name']}"
      end
    end
  end
end
