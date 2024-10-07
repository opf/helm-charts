require 'yaml'
require 'open3'

# HelmTemplate borrowed / adapted from GitLab charts
# as we love the idea of testing our chart with RSpec <3
# https://gitlab.com/gitlab-org/charts/gitlab
class HelmTemplate
  def self.with_defaults(yaml)
    yaml ||= {}
    yaml.is_a?(Hash) ? yaml : YAML.safe_load(yaml)
  end

  def initialize(values, chart = 'openproject')
    debug(values, chart, '14-stable')
  end

  def debug(values, chart, image_tag)
    @values = values

    # Set the default image tag
    if image_tag
      @values["image"] ||= { "tag" => image_tag }
    end

    result = Open3.capture3("helm template --debug optest . -f -",
                            chdir: File.join(__dir__, '..', 'charts', chart),
                            stdin_data: YAML.dump(values))
    @stdout, @stderr, @exit_code = result
    # handle common failures when helm or chart not setup properly
    if @exit_code == 256
      fail "Chart dependencies not installed, run 'helm dependency update'" if @stderr.include? 'found in Chart.yaml, but missing in charts/ directory'
    end

    # load the complete output's YAML documents into an array
    begin
      yaml = YAML.load_stream(@stdout)
      # filter out any empty YAML documents (nil)
      yaml.select! { |x| !x.nil? }
      # create an indexed Hash keyed on Kind/metdata.name
    @mapped = yaml.to_h { |doc|
        ["#{doc['kind']}/#{doc['metadata']['name']}", doc]
      }
    rescue => e
      warn "Failed to parse Helm template output: #{e.message}"
      warn @stdout
      raise e
    end
  end

  def plain
    @stdout
  end

  def [](arg)
    dig(arg)
  end

  def keys
    @mapped.keys
  end

  def dig(*args)
    @mapped.dig(*args)
  end

  def resource_exists?(item)
    @mapped.has_key?(item)
  end

  def volumes(item)
    template_spec(item)
      .dig('volumes')
  end

  def labels(item)
    @mapped.dig(mapped_key(item), 'metadata', 'labels')
  end

  def template_labels(item)
    # only one of the following should return results
    @mapped.dig(mapped_key(item), 'spec', 'template', 'metadata', 'labels') ||
      @mapped.dig(mapped_key(item), 'spec', 'jobTemplate', 'spec', 'template', 'metadata', 'labels')
  end

  def annotations(item)
    @mapped.dig(mapped_key(item), 'metadata', 'annotations')
  end

  def template_annotations(item)
    # only one of the following should return results
    @mapped.dig(mapped_key(item), 'spec', 'template', 'metadata', 'annotations') ||
      @mapped.dig(mapped_key(item), 'spec', 'jobTemplate', 'spec', 'template', 'metadata', 'annotations')
  end

  def mapped_key(item)
    case item
    when Regexp
       keys.find { |k| k.match?(item) }
    else
      item
    end
  end

  def spec(item)
    @mapped.dig(mapped_key(item), 'spec')
  end

  def template_spec(item)
    spec(item).dig('template', 'spec')
  end

  def find_volume(item, volume_name)
    volumes = volumes(item)
    volumes.keep_if { |volume| volume['name'] == volume_name }
    volumes[0]
  end

  def get_projected_secret(item, mount, secret)
    # locate first instance of projected secret by name
    secrets = find_volume(item, mount)
    secrets['projected']['sources'].keep_if do |s|
      s['secret']['name'] == secret if s.has_key?('secret')
    end

    return unless secrets['projected']['sources'].length == 1

    secrets['projected']['sources'][0]['secret']
  end

  def find_projected_secret(item, mount, secret)
    secret = get_projected_secret(item, mount, secret)
    !secret.nil?
  end

  def find_projected_secret_key(item, mount, secret, key)
    secret = get_projected_secret(item, mount, secret)

    result = nil

    if secret&.has_key?('items')

      secret['items'].each do |i|
        if i['key'] == key
          result = i
          break
        end
      end

    end

    result
  end

  def find_volume_mount(item, container_name, volume_name, init = false)
    find_container(item, container_name, init)
      &.dig('volumeMounts')
      &.find { |volume| volume['name'] == volume_name }
  end

  def find_container(item, container_name, init = false)
    containers = init ? 'initContainers' : 'containers'

    template_spec(item)
      &.dig(containers)
      &.find { |container| container['name'] == container_name }
  end

  def find_image(item, container_name, init = false)
    find_container(item, container_name, init)
      &.dig('image')
  end

  def env(item, container_name, init = false)
    find_container(item, container_name, init)
      &.dig('env')
  end

  def env_from(item, container_name, init = false)
    find_container(item, container_name, init)
      &.dig('envFrom')
  end

  def secret_ref(item, container_name, secret_name, init = false)
    env_from(item, container_name, init)
      &.find { |env| env['secretRef']['name'] == secret_name }
  end

  def env_named(item, container_name, key, init = false)
    find_container(item, container_name, init)
      .dig('env')
      .detect { |hash| hash['name'] == key }
  end

  def projected_volume_sources(item, volume_name)
    find_volume(item, volume_name)
      &.dig('projected', 'sources')
  end

  def resources_by_kind(kind)
    @mapped.select { |_, hash| hash['kind'] == kind }
  end

  def exit_code
    @exit_code.to_i
  end

  def stderr
    @stderr
  end

  def stdout
    @stdout
  end

  def values()
    @values
  end
end
