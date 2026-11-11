require 'spec_helper'
require 'open3'
require 'shellwords'
require 'tmpdir'

# Helpers for integration specs that install a chart into a real cluster.
#
# Integration specs are tagged `:integration` and excluded from the default run (see spec_helper.rb).
# They use the current kube context, which must point at a disposable cluster (e.g. k3d or kind):
#
#   bin/rspec --tag integration
#
# Set KEEP_NAMESPACE=1 to keep the test namespaces for debugging.
class KubeNamespace
  class CommandFailed < StandardError; end

  ROOT = File.expand_path('..', __dir__)

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def self.sh(*command, stdin: nil, check: true)
    stdout, stderr, status = Open3.capture3(*command, stdin_data: stdin)
    if check && !status.success?
      raise CommandFailed, "#{command.shelljoin} failed (#{status.exitstatus}):\n#{stdout}\n#{stderr}"
    end

    [stdout, stderr, status]
  end

  def kubectl(*args, stdin: nil, check: true)
    self.class.sh('kubectl', '-n', name, *args, stdin:, check:).first
  end

  # Runs a command in a pod (or `deploy/<name>`) and returns [stdout, success].
  def exec(target, *command, stdin: nil, check: true)
    args = ['exec', (stdin ? '-i' : nil), target, '--', *command].compact
    stdout, _stderr, status = self.class.sh('kubectl', '-n', name, *args, stdin:, check:)
    [stdout, status.success?]
  end

  def apply(yaml)
    kubectl('apply', '-f', '-', stdin: yaml)
  end

  def create!
    # A namespace from a previous run may still be terminating.
    self.class.sh('kubectl', 'wait', '--for=delete', "namespace/#{name}", '--timeout=300s', check: false)
    self.class.sh('kubectl', 'create', 'namespace', name)
  end

  def delete
    return if ENV['KEEP_NAMESPACE']

    self.class.sh('kubectl', 'delete', 'namespace', name, '--wait=false', check: false)
  end

  # Makes the namespace enforce the given Pod Security Standard for all pods created from now on.
  def enforce_pod_security!(level)
    self.class.sh('kubectl', 'label', '--overwrite', 'namespace', name,
                  "pod-security.kubernetes.io/enforce=#{level}", 'pod-security.kubernetes.io/enforce-version=latest')
  end

  def secret_value(secret, key)
    kubectl('get', 'secret', secret, '-o', "jsonpath={.data.#{key}}").unpack1('m')
  end

  def helm_install(release, chart, *args)
    self.class.sh('helm', 'upgrade', '--install', release, File.join(ROOT, 'charts', chart), '-n', name, *args)
  end

  # Creates a job from a CronJob and waits for it to succeed. Fails as soon as any container
  # fails once instead of waiting for all retries. Returns the job's logs.
  def run_cronjob(cronjob, job, timeout: 600)
    kubectl('create', 'job', job, "--from=cronjob/#{cronjob}")
    wait_for_job(job, timeout:)
  end

  def wait_for_job(job, timeout: 600)
    deadline = Time.now + timeout
    loop do
      return logs(job) if kubectl('get', 'job', job, '-o', 'jsonpath={.status.succeeded}') == '1'

      if job_failed?(job)
        sleep 2
        raise CommandFailed, "job #{job} failed:\n#{logs(job, previous: true)}\n#{logs(job)}"
      end
      raise CommandFailed, "job #{job} timed out:\n#{logs(job)}" if Time.now > deadline

      sleep 5
    end
  end

  def logs(job, previous: false)
    args = ['logs', "job/#{job}", '--all-containers', '--prefix']
    args << '--previous' if previous
    kubectl(*args, check: false)
  end

  private

  def job_failed?(job)
    restarts = kubectl(
      'get', 'pods', '-l', "job-name=#{job}", '-o',
      'jsonpath={range .items[*]}{range .status.initContainerStatuses[*]}{.restartCount} {end}' \
      '{range .status.containerStatuses[*]}{.restartCount} {end}{end}'
    ).split.map(&:to_i)

    restarts.any?(&:positive?) || !kubectl('get', 'job', job, '-o', 'jsonpath={.status.failed}').empty?
  end
end
