# frozen_string_literal: true
require 'integration_helper'
require 'json'

# End-to-end test for the chart's kopia backups.
#
# Installs OpenProject with backups and replication enabled, backed by two independent
# in-cluster S3 services (rustfs), writes marker data, runs two backups, the replication and the
# verification job, and then restores the latest snapshot from both repositories. A minimal HTTP
# server stands in for the heartbeat monitor pinged after successful backups and verifications.
#
#   bin/rspec --tag integration spec/charts/openproject/integration/backup_spec.rb
#
# Scenarios (set ATTACHMENTS=<scenario> to run only one of them):
#   local   attachments on the assets volume, in a namespace enforcing the "restricted" Pod Security Standard
#   s3      attachments in S3, mounted by the backup via FUSE (privileged)
#   s3-csi  attachments in S3, provided as a volume by an S3 CSI driver (k8s-csi-s3, installed into
#           kube-system), in a namespace enforcing "restricted"
# The s3 scenario also checks that installing FUSE-based backups into a restricted namespace fails.
describe 'backups', :integration do
  fixtures = File.join(__dir__, 'backup')
  test_values = YAML.load_file(File.join(fixtures, 'values.yaml'))
  chart_values = YAML.load_file(File.join(KubeNamespace::ROOT, 'charts/openproject/values.yaml'))

  release = 'openproject'
  rustfs_image = ENV.fetch('RUSTFS_IMAGE', 'rustfs/rustfs:1.0.4')
  heartbeat_image = ENV.fetch('HEARTBEAT_IMAGE', 'busybox:1.37')
  kopia_image = chart_values['backup']['image'].values_at('registry', 'repository').join('/') +
                ":#{chart_values['backup']['image']['tag']}"

  # The two S3 services, with the buckets the chart is configured to use.
  repositories = {
    'primary' => { service: 'backup-s3', s3: test_values['backup']['s3'] },
    'replica' => { service: 'replica-s3', s3: test_values['backup']['replica']['s3'] }
  }
  attachments_bucket = 'openproject-attachments'

  s3_values = File.join(fixtures, 'values-s3-attachments.yaml')
  scenarios = {
    'local' => {
      values: [], restricted: true,
      description: 'with attachments on the assets volume in a restricted namespace'
    },
    's3' => {
      values: [s3_values], restricted: false,
      description: 'with attachments in S3 mounted via FUSE'
    },
    's3-csi' => {
      values: [s3_values, File.join(fixtures, 'values-s3-csi.yaml')], restricted: true, csi: true,
      description: 'with attachments in S3 mounted via a CSI driver in a restricted namespace'
    }
  }
  run_scenario = ->(name) { ENV['ATTACHMENTS'].nil? || ENV['ATTACHMENTS'] == name }

  if run_scenario.call('s3')
    context 'with attachments in S3 mounted via FUSE in a restricted namespace' do
      before(:context) do
        @kube = KubeNamespace.new('backup-test-s3-restricted')
        @kube.create!
        @kube.enforce_pod_security!('restricted')
      end

      after(:context) do
        @kube&.delete
      end

      it 'refuses to install, as the privileged backup pods would be rejected', :aggregate_failures do
        _, stderr, status = KubeNamespace.sh(
          'helm', 'upgrade', '--install', release, File.join(KubeNamespace::ROOT, 'charts/openproject'),
          '-n', @kube.name, '-f', File.join(fixtures, 'values.yaml'), '-f', s3_values, '--dry-run=server',
          check: false
        )

        expect(status).not_to be_success
        expect(stderr).to include('enforces the "restricted" Pod Security Standard')
        expect(stderr).to include('backup.s3Attachments.existingClaim')
      end
    end
  end

  scenarios.select { |name, _| run_scenario.call(name) }.each do |attachments, scenario|
    context scenario[:description] do
      # Plain methods instead of `let`, as they are needed in before(:context) hooks.
      def kube = @kube
      def toolbox = 'pod/toolbox'
      def token = @token

      # rclone remote names for the S3 services, as configured in the toolbox pod.
      def remote(service)
        service.tr('-', '_')
      end

      def deploy_s3(service)
        kube.apply(<<~YAML)
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: #{service}
          spec:
            selector:
              matchLabels: { app: #{service} }
            template:
              metadata:
                labels: { app: #{service} }
              spec:
                containers:
                  - name: rustfs
                    image: #{@rustfs_image}
                    env:
                      - { name: RUSTFS_ACCESS_KEY, value: "#{service}-access" }
                      - { name: RUSTFS_SECRET_KEY, value: "#{service}-secret-key" }
                      - { name: RUSTFS_VOLUMES, value: /data }
                      - { name: RUSTFS_ADDRESS, value: ":9000" }
                    ports:
                      - containerPort: 9000
                    readinessProbe:
                      httpGet: { path: /health, port: 9000 }
                    volumeMounts:
                      - { name: data, mountPath: /data }
                volumes:
                  - name: data
                    emptyDir: {}
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: #{service}
          spec:
            selector: { app: #{service} }
            ports:
              - port: 9000
        YAML
      end

      # A stand-in for a heartbeat monitor (e.g. UptimeRobot): an HTTP server answering any of the
      # heartbeat URLs configured in backup/values.yaml and logging each request ("url:/<path>").
      def deploy_heartbeat_monitor
        kube.apply(<<~YAML)
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: heartbeat
          spec:
            selector:
              matchLabels: { app: heartbeat }
            template:
              metadata:
                labels: { app: heartbeat }
              spec:
                containers:
                  - name: httpd
                    image: #{@heartbeat_image}
                    command:
                      - sh
                      - -c
                      - mkdir -p /tmp/www && touch /tmp/www/backup /tmp/www/replica /tmp/www/verification /tmp/www/ok && exec httpd -f -vv -p 8080 -h /tmp/www
                    ports:
                      - containerPort: 8080
                    readinessProbe:
                      tcpSocket: { port: 8080 }
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: heartbeat
          spec:
            selector: { app: heartbeat }
            ports:
              - port: 8080
        YAML
      end

      # The number of successful heartbeat requests received for the given path.
      def heartbeats(path)
        log = kube.kubectl('logs', 'deploy/heartbeat')
        requests = log.scan(/^(\S+): url:(\S+)$/).to_h
        responses = log.scan(/^(\S+): response:(\d+)$/).to_h
        requests.count { |client, url| url == path && responses[client] == '200' }
      end

      # A long-running pod with the chart's kopia image (which ships rclone) to inspect the buckets
      # and restore snapshots. rclone remotes "backup_s3:" and "replica_s3:" are preconfigured.
      def deploy_toolbox
        env = %w[backup-s3 replica-s3].flat_map do |service|
          prefix = "RCLONE_CONFIG_#{remote(service).upcase}"
          {
            "#{prefix}_TYPE" => 's3', "#{prefix}_PROVIDER" => 'Other',
            "#{prefix}_ENDPOINT" => "http://#{service}:9000",
            "#{prefix}_ACCESS_KEY_ID" => "#{service}-access", "#{prefix}_SECRET_ACCESS_KEY" => "#{service}-secret-key"
          }.to_a
        end
        env << %w[RCLONE_LOG_LEVEL ERROR]

        kube.apply(YAML.dump(
          'apiVersion' => 'v1', 'kind' => 'Pod', 'metadata' => { 'name' => 'toolbox' },
          'spec' => {
            'securityContext' => {
              'runAsNonRoot' => true, 'runAsUser' => 1000, 'seccompProfile' => { 'type' => 'RuntimeDefault' }
            },
            'containers' => [{
              'name' => 'toolbox', 'image' => @kopia_image, 'imagePullPolicy' => 'IfNotPresent',
              'command' => %w[sleep infinity],
              'env' => env.map { |name, value| { 'name' => name, 'value' => value } },
              'securityContext' => { 'allowPrivilegeEscalation' => false, 'capabilities' => { 'drop' => ['ALL'] } }
            }]
          }
        ))
        kube.kubectl('wait', '--for=condition=Ready', toolbox, '--timeout=180s')
      end

      # Installs the k8s-csi-s3 driver (cluster-wide, into kube-system) and provides the attachments
      # bucket as the PVC "openproject-attachments" via a statically provisioned PersistentVolume,
      # as described in the chart's README.
      def provide_attachments_volume
        KubeNamespace.sh(
          'helm', 'upgrade', '--install', 'csi-s3', 'csi-s3', '--repo', 'https://yandex-cloud.github.io/k8s-csi-s3/charts',
          '--version', '0.43.7', '-n', 'kube-system', '--set', 'secret.create=false', '--set', 'storageClass.create=false',
          '--wait', '--timeout', '5m'
        )

        kube.apply(<<~YAML)
          apiVersion: v1
          kind: Secret
          metadata:
            name: attachments-s3-csi
          stringData:
            accessKeyID: backup-s3-access
            secretAccessKey: backup-s3-secret-key
            # The driver runs in kube-system.
            endpoint: http://backup-s3.#{kube.name}.svc.cluster.local:9000
          ---
          apiVersion: v1
          kind: PersistentVolume
          metadata:
            name: #{attachments_volume}
          spec:
            capacity:
              storage: 10Gi
            accessModes: [ReadWriteMany]
            claimRef:
              namespace: #{kube.name}
              name: openproject-attachments
            csi:
              driver: ru.yandex.s3.csi
              volumeHandle: #{@attachments_bucket}
              nodePublishSecretRef: { name: attachments-s3-csi, namespace: #{kube.name} }
              nodeStageSecretRef: { name: attachments-s3-csi, namespace: #{kube.name} }
              volumeAttributes:
                mounter: geesefs
                # --no-systemd: run geesefs in the driver pod, as kind/k3d nodes have no systemd.
                options: --memory-limit 1000 --dir-mode 0777 --file-mode 0666 --no-systemd
          ---
          apiVersion: v1
          kind: PersistentVolumeClaim
          metadata:
            name: openproject-attachments
          spec:
            storageClassName: ""
            volumeName: #{attachments_volume}
            accessModes: [ReadWriteMany]
            resources:
              requests:
                storage: 10Gi
        YAML
      end

      def attachments_volume = "#{kube.name}-attachments"

      def tool(*command, stdin: nil, check: true)
        kube.exec(toolbox, *command, stdin:, check:)
      end

      def write_markers(token)
        pg_password = kube.secret_value("#{@release}-postgresql", 'password')
        kube.exec(
          "#{@release}-postgresql-0", 'env', "PGPASSWORD=#{pg_password}",
          'psql', '-h', '127.0.0.1', '-U', 'openproject', '-d', 'openproject', '-v', 'ON_ERROR_STOP=1', '-q', '-c',
          "CREATE TABLE IF NOT EXISTS backup_test_marker (token text); " \
          "TRUNCATE backup_test_marker; INSERT INTO backup_test_marker VALUES ('#{token}');"
        )

        # One marker each in the attachments and the custom styles, the two directories that are backed up.
        %w[attachment custom_style].each do |dir|
          if @s3
            tool('rclone', 'rcat', "backup_s3:#{@attachments_bucket}/uploads/#{dir}/backup-test/marker.txt",
                 stdin: "#{token}\n")
          else
            path = "/var/openproject/assets/files/#{dir}/backup-test"
            kube.exec("deploy/#{@release}-web", 'sh', '-c', "mkdir -p #{path} && echo #{token} > #{path}/marker.txt")
          end
        end
      end

      # kopia command line arguments to connect to a repository.
      def kopia_repository_args(repository)
        s3 = repository[:s3]
        [
          '--endpoint', s3['endpoint'].delete_prefix('http://'), '--disable-tls',
          '--bucket', s3['bucket'],
          '--access-key', s3['auth']['accessKeyId'], '--secret-access-key', s3['auth']['secretAccessKey']
        ]
      end

      def kopia(repository_name, *args, password: @kopia_password, check: true)
        tool('env', "KOPIA_PASSWORD=#{password}",
             "KOPIA_CONFIG_PATH=/tmp/kopia-#{repository_name}/repository.config",
             "KOPIA_CACHE_DIRECTORY=/tmp/kopia-#{repository_name}/cache",
             'kopia', *args, check:)
      end

      before(:context) do
        @release = release
        @attachments = attachments
        @s3 = attachments.start_with?('s3')
        @attachments_bucket = attachments_bucket
        @rustfs_image = rustfs_image
        @heartbeat_image = heartbeat_image
        @kopia_image = kopia_image
        @kube = KubeNamespace.new("backup-test-#{attachments}")

        kube.create!
        deploy_s3('backup-s3')
        deploy_s3('replica-s3')
        deploy_heartbeat_monitor
        %w[backup-s3 replica-s3 heartbeat].each { |deployment| kube.kubectl('rollout', 'status', "deploy/#{deployment}", '--timeout=180s') }
        deploy_toolbox

        # The chart expects the buckets to exist.
        repositories.each_value { |repo| tool('rclone', 'mkdir', "#{remote(repo[:service])}:#{repo[:s3]['bucket']}") }
        tool('rclone', 'mkdir', "backup_s3:#{attachments_bucket}") if @s3
        provide_attachments_volume if scenario[:csi]

        # Enforced from here on, so it applies to everything the chart deploys. The S3 services, the
        # heartbeat monitor and the toolbox above (test infrastructure) are already running and not affected.
        kube.enforce_pod_security!('restricted') if scenario[:restricted]

        kube.helm_install(
          release, 'openproject',
          '-f', File.join(fixtures, 'values.yaml'), *scenario[:values].flat_map { |file| ['-f', file] },
          '--wait', '--timeout', '20m'
        )
        @kopia_password = kube.secret_value('backup-kopia-password-auto-generated', 'kopiaPassword')

        # The first backup creates the kopia repository, the second one connects to the existing one.
        write_markers("first-#{rand(10**9)}")
        kube.run_cronjob("#{release}-backup", 'backup-1')
        @heartbeats_after_first_backup = heartbeats('/backup')
        @token = "second-#{rand(10**9)}"
        write_markers(@token)
        kube.run_cronjob("#{release}-backup", 'backup-2')

        @replica_heartbeats_before_replication = heartbeats('/replica')
        @verification_heartbeats_before_verification = heartbeats('/verification')
        kube.run_cronjob("#{release}-backup-replica", 'replica-1')
        @verification_logs = kube.run_cronjob("#{release}-backup-verification", 'verification-1')
      end

      after(:context) do
        @kube&.delete
        KubeNamespace.sh('kubectl', 'delete', 'pv', attachments_volume, '--wait=false', check: false) if scenario[:csi] && !ENV['KEEP_NAMESPACE']
      end

      it 'verifies the backup' do
        expect(@verification_logs).to include('Verification of backup complete')
      end

      it 'pings the backup heartbeat after each backup', :aggregate_failures do
        expect(@heartbeats_after_first_backup).to eq(1)
        expect(heartbeats('/backup')).to eq(2)
      end

      it 'pings the replication heartbeat only after a replication', :aggregate_failures do
        expect(@replica_heartbeats_before_replication).to eq(0)
        expect(heartbeats('/replica')).to eq(1)
      end

      it 'pings the verification heartbeat only after a verification', :aggregate_failures do
        expect(@verification_heartbeats_before_verification).to eq(0)
        expect(heartbeats('/verification')).to eq(1)
      end

      # Runs the chart's heartbeat script in the toolbox pod, which uses the same image as the jobs.
      def send_heartbeat(url)
        script = File.read(File.join(KubeNamespace::ROOT, 'charts/openproject/files/backup/heartbeat.sh'))
        tool('bash', '-s', '--', url, stdin: script, check: false)
      end

      it 'does not fail a job if the heartbeat monitor responds with an error', :aggregate_failures do
        output, success = send_heartbeat('http://heartbeat:8080/missing')

        expect(success).to be(true)
        expect(output).to include('Warning: failed to send the heartbeat')
        expect(kube.kubectl('logs', 'deploy/heartbeat').scan('url:/missing').size).to eq(4), 'expected 3 retries'
      end

      it 'does not fail a job if the heartbeat monitor is unreachable', :aggregate_failures do
        output, success = send_heartbeat('http://no-such-monitor:8080/backup')

        expect(success).to be(true)
        expect(output).to include('Warning: failed to send the heartbeat')
      end

      it 'does not print a warning for a successful heartbeat' do
        output, = send_heartbeat('http://heartbeat:8080/ok')
        expect(output).not_to include('Warning')
      end

      it 'does not write anything into the attachments' do
        entries =
          if @s3
            tool('rclone', 'lsf', "backup_s3:#{attachments_bucket}").first.split +
              tool('rclone', 'lsf', "backup_s3:#{attachments_bucket}/uploads").first.split
          else
            kube.exec("deploy/#{release}-web", 'ls', '-A', '/var/openproject/assets', '/var/openproject/assets/files')
                .first.split.reject { |line| line.end_with?(':') }
          end

        expect(entries.map { |entry| entry.delete_suffix('/') } - %w[files uploads attachment custom_style lost+found])
          .to be_empty
      end

      repositories.each do |repository_name, repository|
        context "restoring from the #{repository_name} repository" do
          def restored = @restored

          before(:context) do
            kopia(repository_name, 'repository', 'connect', 's3', *kopia_repository_args(repository), '--readonly')
            snapshots = JSON.parse(kopia(repository_name, 'snapshot', 'list', '--all', '--json').first)
            @snapshot_count = snapshots.size

            restore_path = "/tmp/restore-#{repository_name}"
            kopia(repository_name, 'snapshot', 'restore', snapshots.last['id'], restore_path)

            @tmpdir = Dir.mktmpdir("backup-#{repository_name}")
            @restored = File.join(@tmpdir, 'restore')
            kube.kubectl('cp', "toolbox:#{restore_path}", @restored)
          end

          after(:context) do
            FileUtils.rm_rf(@tmpdir) if @tmpdir
          end

          it 'stores a kopia repository in the bucket' do
            objects = tool('rclone', 'lsf', "#{remote(repository[:service])}:#{repository[:s3]['bucket']}").first.split
            expect(objects).to include('kopia.repository')
          end

          it 'encrypts the stored data' do
            raw = "/tmp/raw-#{repository_name}"
            tool('rclone', 'copy', "#{remote(repository[:service])}:#{repository[:s3]['bucket']}", raw)
            _, found = tool('grep', '-r', '-q', '-F', token, raw, check: false)

            expect(found).to be(false), 'marker found in plaintext in the raw bucket contents'
          end

          it 'rejects a wrong password' do
            _, connected = kopia(
              repository_name, 'repository', 'connect', 's3', *kopia_repository_args(repository), '--readonly',
              '--config-file', "/tmp/kopia-#{repository_name}/wrong-password.config",
              password: 'definitely-wrong', check: false
            )

            expect(connected).to be(false)
          end

          it 'contains a snapshot for each backup' do
            expect(@snapshot_count).to eq(2)
          end

          it 'has the same layout as OpenProject backups' do
            expect(Dir.children(restored)).to match_array(%w[openproject.sql attachment custom_style])
          end

          it 'restores the latest attachments and custom styles', :aggregate_failures do
            %w[attachment custom_style].each do |dir|
              expect(File.read(File.join(restored, dir, 'backup-test/marker.txt')).strip).to eq(token)
            end
            expect(Dir.glob(File.join(restored, 'attachment/file/*/*'))).not_to be_empty
          end

          it 'restores a complete database dump with the latest data', :aggregate_failures do
            dump = File.read(File.join(restored, 'openproject.sql'))

            expect(dump.lines.last(5).join).to include('-- PostgreSQL database dump complete')
            expect(dump).to include('CREATE TABLE public.work_packages ')
            expect(dump[/^COPY public\.backup_test_marker .*?\n\\\./m]).to include("\n#{token}\n")
          end
        end
      end
    end
  end
end
