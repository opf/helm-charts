# frozen_string_literal: true
require 'spec_helper'

describe 'commonLabels and commonAnnotations' do
  let(:template) { HelmTemplate.new(default_values) }

  context 'with default values' do
    let(:default_values) { {} }

    it 'applies default common labels to all resources' do
      # Test web deployment
      web_labels = template.labels('Deployment/optest-openproject-web')
      expect(web_labels).to include('app.kubernetes.io/name' => 'openproject')
      expect(web_labels).to include('app.kubernetes.io/instance' => 'optest')
      expect(web_labels).to include('openproject/process' => 'web')

      # Test worker deployment
      worker_labels = template.labels('Deployment/optest-openproject-worker-default')
      expect(worker_labels).to include('app.kubernetes.io/name' => 'openproject')
      expect(worker_labels).to include('app.kubernetes.io/instance' => 'optest')
      expect(worker_labels).to include('openproject/process' => 'worker-default')

      # Test service
      service_labels = template.labels('Service/optest-openproject')
      expect(service_labels).to include('app.kubernetes.io/name' => 'openproject')
      expect(service_labels).to include('app.kubernetes.io/instance' => 'optest')

      # Test ingress
      ingress_labels = template.labels('Ingress/optest-openproject')
      expect(ingress_labels).to include('app.kubernetes.io/name' => 'openproject')
      expect(ingress_labels).to include('app.kubernetes.io/instance' => 'optest')
    end

    it 'does not add common annotations when not specified' do
      # Test that common annotations are not present when not configured
      web_annotations = template.annotations('Deployment/optest-openproject-web')
      expect(web_annotations).to be_nil

      service_annotations = template.annotations('Service/optest-openproject')
      expect(service_annotations).to be_nil
    end
  end

  context 'with custom commonLabels' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonLabels:
          environment: production
          team: platform
          version: "1.0.0"
          custom-label: "custom-value"
      YAML
      )
    end

    it 'applies custom common labels to all resources', :aggregate_failures do
      # Test web deployment
      web_labels = template.labels('Deployment/optest-openproject-web')
      expect(web_labels).to include('environment' => 'production')
      expect(web_labels).to include('team' => 'platform')
      expect(web_labels).to include('version' => '1.0.0')
      expect(web_labels).to include('custom-label' => 'custom-value')
      expect(web_labels).to include('openproject/process' => 'web')

      # Test worker deployment
      worker_labels = template.labels('Deployment/optest-openproject-worker-default')
      expect(worker_labels).to include('environment' => 'production')
      expect(worker_labels).to include('team' => 'platform')
      expect(worker_labels).to include('version' => '1.0.0')
      expect(worker_labels).to include('custom-label' => 'custom-value')

      # Test service
      service_labels = template.labels('Service/optest-openproject')
      expect(service_labels).to include('environment' => 'production')
      expect(service_labels).to include('team' => 'platform')
      expect(service_labels).to include('version' => '1.0.0')
      expect(service_labels).to include('custom-label' => 'custom-value')

      # Test ingress
      ingress_labels = template.labels('Ingress/optest-openproject')
      expect(ingress_labels).to include('environment' => 'production')
      expect(ingress_labels).to include('team' => 'platform')
      expect(ingress_labels).to include('version' => '1.0.0')
      expect(ingress_labels).to include('custom-label' => 'custom-value')

      # Test PVC
      pvc_labels = template.labels('PersistentVolumeClaim/optest-openproject')
      expect(pvc_labels).to include('environment' => 'production')
      expect(pvc_labels).to include('team' => 'platform')
      expect(pvc_labels).to include('version' => '1.0.0')
      expect(pvc_labels).to include('custom-label' => 'custom-value')

      # Test ServiceAccount
      sa_labels = template.labels('ServiceAccount/optest-openproject')
      expect(sa_labels).to include('environment' => 'production')
      expect(sa_labels).to include('team' => 'platform')
      expect(sa_labels).to include('version' => '1.0.0')
      expect(sa_labels).to include('custom-label' => 'custom-value')
    end

    context 'with cron enabled' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          commonLabels:
            environment: production
            team: platform
          cron:
            enabled: true
        YAML
        )
      end

      it 'applies common labels to cron deployment' do
        cron_labels = template.labels('Deployment/optest-openproject-cron')
        expect(cron_labels).to include('environment' => 'production')
        expect(cron_labels).to include('team' => 'platform')
        expect(cron_labels).to include('openproject/process' => 'cron')
      end
    end
  end

  context 'with custom commonAnnotations' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonAnnotations:
          monitoring.io/scrape: "true"
          monitoring.io/port: "8080"
          team: platform
          environment: production
      YAML
      )
    end

    it 'applies common annotations to resources that support them', :aggregate_failures do
      # Test web deployment
      web_annotations = template.annotations('Deployment/optest-openproject-web')
      expect(web_annotations).to include('monitoring.io/scrape' => 'true')
      expect(web_annotations).to include('monitoring.io/port' => '8080')
      expect(web_annotations).to include('team' => 'platform')
      expect(web_annotations).to include('environment' => 'production')

      # Test service
      service_annotations = template.annotations('Service/optest-openproject')
      expect(service_annotations).to include('monitoring.io/scrape' => 'true')
      expect(service_annotations).to include('monitoring.io/port' => '8080')
      expect(service_annotations).to include('team' => 'platform')
      expect(service_annotations).to include('environment' => 'production')

      # Test ingress
      ingress_annotations = template.annotations('Ingress/optest-openproject')
      expect(ingress_annotations).to include('monitoring.io/scrape' => 'true')
      expect(ingress_annotations).to include('monitoring.io/port' => '8080')
      expect(ingress_annotations).to include('team' => 'platform')
      expect(ingress_annotations).to include('environment' => 'production')
    end

    context 'with resource-specific annotations' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          commonAnnotations:
            monitoring.io/scrape: "true"
            team: platform
          openproject:
            annotations:
              custom.io/annotation: "web-specific"
              monitoring.io/scrape: "false"  # This should override common annotation
          ingress:
            annotations:
              nginx.ingress.kubernetes.io/rewrite-target: "/"
              custom.io/annotation: "ingress-specific"
        YAML
        )
      end

      it 'merges common and resource-specific annotations with resource-specific taking precedence', :aggregate_failures do
        # Test web deployment - should have merged annotations
        web_annotations = template.annotations('Deployment/optest-openproject-web')
        expect(web_annotations).to include('monitoring.io/scrape' => 'false')  # Resource-specific overrides common
        expect(web_annotations).to include('team' => 'platform')  # From common
        expect(web_annotations).to include('custom.io/annotation' => 'web-specific')  # Resource-specific

        # Test ingress - should have merged annotations
        ingress_annotations = template.annotations('Ingress/optest-openproject')
        expect(ingress_annotations).to include('monitoring.io/scrape' => 'true')  # From common (no override)
        expect(ingress_annotations).to include('team' => 'platform')  # From common
        expect(ingress_annotations).to include('nginx.ingress.kubernetes.io/rewrite-target' => '/')  # Resource-specific
        expect(ingress_annotations).to include('custom.io/annotation' => 'ingress-specific')  # Resource-specific
      end
    end

    context 'with cron enabled and annotations' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          commonAnnotations:
            monitoring.io/scrape: "true"
            team: platform
          cron:
            enabled: true
            annotations:
              custom.io/cron-annotation: "cron-specific"
              monitoring.io/scrape: "false"  # This should override common annotation
        YAML
        )
      end

      it 'applies merged annotations to cron deployment' do
        cron_annotations = template.annotations('Deployment/optest-openproject-cron')
        expect(cron_annotations).to include('monitoring.io/scrape' => 'false')  # Resource-specific overrides common
        expect(cron_annotations).to include('team' => 'platform')  # From common
        expect(cron_annotations).to include('custom.io/cron-annotation' => 'cron-specific')  # Resource-specific
      end
    end
  end

  context 'with both commonLabels and commonAnnotations' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonLabels:
          environment: production
          team: platform
          version: "2.0.0"
        commonAnnotations:
          monitoring.io/scrape: "true"
          monitoring.io/port: "8080"
          team: platform
          environment: production
        openproject:
          annotations:
            custom.io/web-annotation: "web-specific"
        ingress:
          annotations:
            nginx.ingress.kubernetes.io/rewrite-target: "/"
      YAML
      )
    end

    it 'applies both labels and annotations correctly', :aggregate_failures do
      # Test web deployment
      web_labels = template.labels('Deployment/optest-openproject-web')
      web_annotations = template.annotations('Deployment/optest-openproject-web')

      expect(web_labels).to include('environment' => 'production')
      expect(web_labels).to include('team' => 'platform')
      expect(web_labels).to include('version' => '2.0.0')
      expect(web_labels).to include('openproject/process' => 'web')

      expect(web_annotations).to include('monitoring.io/scrape' => 'true')
      expect(web_annotations).to include('monitoring.io/port' => '8080')
      expect(web_annotations).to include('team' => 'platform')
      expect(web_annotations).to include('environment' => 'production')
      expect(web_annotations).to include('custom.io/web-annotation' => 'web-specific')

      # Test service
      service_labels = template.labels('Service/optest-openproject')
      service_annotations = template.annotations('Service/optest-openproject')

      expect(service_labels).to include('environment' => 'production')
      expect(service_labels).to include('team' => 'platform')
      expect(service_labels).to include('version' => '2.0.0')

      expect(service_annotations).to include('monitoring.io/scrape' => 'true')
      expect(service_annotations).to include('monitoring.io/port' => '8080')
      expect(service_annotations).to include('team' => 'platform')
      expect(service_annotations).to include('environment' => 'production')

      # Test ingress
      ingress_labels = template.labels('Ingress/optest-openproject')
      ingress_annotations = template.annotations('Ingress/optest-openproject')

      expect(ingress_labels).to include('environment' => 'production')
      expect(ingress_labels).to include('team' => 'platform')
      expect(ingress_labels).to include('version' => '2.0.0')

      expect(ingress_annotations).to include('monitoring.io/scrape' => 'true')
      expect(ingress_annotations).to include('monitoring.io/port' => '8080')
      expect(ingress_annotations).to include('team' => 'platform')
      expect(ingress_annotations).to include('environment' => 'production')
      expect(ingress_annotations).to include('nginx.ingress.kubernetes.io/rewrite-target' => '/')
    end
  end

  context 'with web-specific labels and annotations' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonLabels:
          environment: production
          team: backend
        commonAnnotations:
          monitoring.io/scrape: "true"
        web:
          labels:
            tier: web
            component: frontend
            custom-web-label: "web-specific-value"
          annotations:
            custom.io/web-annotation: "web-specific-annotation"
            monitoring.io/port: "8080"
      YAML
      )
    end

    it 'applies web-specific labels to web deployment only', :aggregate_failures do
      web_labels = template.labels('Deployment/optest-openproject-web')

      # Test common labels are applied
      expect(web_labels).to include('environment' => 'production')
      expect(web_labels).to include('team' => 'backend')

      # Test web-specific labels are applied
      expect(web_labels).to include('tier' => 'web')
      expect(web_labels).to include('component' => 'frontend')
      expect(web_labels).to include('custom-web-label' => 'web-specific-value')

      # Test web-specific process label
      expect(web_labels).to include('openproject/process' => 'web')

      # Test standard Helm labels are present
      expect(web_labels).to include('app.kubernetes.io/name' => 'openproject')
      expect(web_labels).to include('app.kubernetes.io/instance' => 'optest')
    end

    it 'applies web-specific annotations to web deployment only', :aggregate_failures do
      web_annotations = template.annotations('Deployment/optest-openproject-web')

      # Test common annotations are applied
      expect(web_annotations).to include('monitoring.io/scrape' => 'true')

      # Test web-specific annotations are applied
      expect(web_annotations).to include('custom.io/web-annotation' => 'web-specific-annotation')
      expect(web_annotations).to include('monitoring.io/port' => '8080')
    end

    it 'does not apply web-specific labels to other resources', :aggregate_failures do
      # Worker deployment should not have web-specific labels
      worker_labels = template.labels('Deployment/optest-openproject-worker-default')
      expect(worker_labels).to include('environment' => 'production')
      expect(worker_labels).to include('team' => 'backend')
      expect(worker_labels).to include('openproject/process' => 'worker-default')
      expect(worker_labels).not_to include('tier' => 'web')
      expect(worker_labels).not_to include('component' => 'frontend')
      expect(worker_labels).not_to include('custom-web-label' => 'web-specific-value')

      # Service should have common labels but not process-specific labels
      service_labels = template.labels('Service/optest-openproject')
      expect(service_labels).to include('environment' => 'production')
      expect(service_labels).to include('team' => 'backend')
      expect(service_labels).not_to include('openproject/process')
      expect(service_labels).not_to include('tier' => 'web')
    end
  end

  context 'with worker-specific labels and annotations' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonLabels:
          environment: production
          team: backend
        commonAnnotations:
          monitoring.io/scrape: "true"
        worker:
          labels:
            tier: worker
            component: background
            custom-worker-label: "worker-specific-value"
          annotations:
            custom.io/worker-annotation: "worker-specific-annotation"
            monitoring.io/port: "8080"
      YAML
      )
    end

    it 'applies worker-specific labels to worker deployment only', :aggregate_failures do
      worker_labels = template.labels('Deployment/optest-openproject-worker-default')

      # Test common labels are applied
      expect(worker_labels).to include('environment' => 'production')
      expect(worker_labels).to include('team' => 'backend')

      # Test worker-specific labels are applied
      expect(worker_labels).to include('tier' => 'worker')
      expect(worker_labels).to include('component' => 'background')
      expect(worker_labels).to include('custom-worker-label' => 'worker-specific-value')

      # Test worker-specific process label
      expect(worker_labels).to include('openproject/process' => 'worker-default')

      # Test standard Helm labels are present
      expect(worker_labels).to include('app.kubernetes.io/name' => 'openproject')
      expect(worker_labels).to include('app.kubernetes.io/instance' => 'optest')
    end

    it 'applies worker-specific annotations to worker deployment only', :aggregate_failures do
      worker_annotations = template.annotations('Deployment/optest-openproject-worker-default')

      # Test common annotations are applied
      expect(worker_annotations).to include('monitoring.io/scrape' => 'true')

      # Test worker-specific annotations are applied
      expect(worker_annotations).to include('custom.io/worker-annotation' => 'worker-specific-annotation')
      expect(worker_annotations).to include('monitoring.io/port' => '8080')
    end

    it 'does not apply worker-specific labels to other resources', :aggregate_failures do
      # Web deployment should not have worker-specific labels
      web_labels = template.labels('Deployment/optest-openproject-web')
      expect(web_labels).to include('environment' => 'production')
      expect(web_labels).to include('team' => 'backend')
      expect(web_labels).to include('openproject/process' => 'web')
      expect(web_labels).not_to include('tier' => 'worker')
      expect(web_labels).not_to include('component' => 'background')
      expect(web_labels).not_to include('custom-worker-label' => 'worker-specific-value')

      # Service should have common labels but not process-specific labels
      service_labels = template.labels('Service/optest-openproject')
      expect(service_labels).to include('environment' => 'production')
      expect(service_labels).to include('team' => 'backend')
      expect(service_labels).not_to include('openproject/process')
      expect(service_labels).not_to include('tier' => 'worker')
    end
  end

  context 'with both web and worker specific labels' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonLabels:
          environment: production
          team: backend
        commonAnnotations:
          monitoring.io/scrape: "true"
        web:
          labels:
            tier: web
            component: frontend
            custom-web-label: "web-specific-value"
          annotations:
            custom.io/web-annotation: "web-specific-annotation"
        worker:
          labels:
            tier: worker
            component: background
            custom-worker-label: "worker-specific-value"
          annotations:
            custom.io/worker-annotation: "worker-specific-annotation"
      YAML
      )
    end

    it 'applies correct labels to each deployment type', :aggregate_failures do
      # Web deployment gets common + web-specific labels
      web_labels = template.labels('Deployment/optest-openproject-web')
      expect(web_labels).to include('environment' => 'production')
      expect(web_labels).to include('team' => 'backend')
      expect(web_labels).to include('tier' => 'web')
      expect(web_labels).to include('component' => 'frontend')
      expect(web_labels).to include('custom-web-label' => 'web-specific-value')
      expect(web_labels).to include('openproject/process' => 'web')

      # Worker deployment gets common + worker-specific labels
      worker_labels = template.labels('Deployment/optest-openproject-worker-default')
      expect(worker_labels).to include('environment' => 'production')
      expect(worker_labels).to include('team' => 'backend')
      expect(worker_labels).to include('tier' => 'worker')
      expect(worker_labels).to include('component' => 'background')
      expect(worker_labels).to include('custom-worker-label' => 'worker-specific-value')
      expect(worker_labels).to include('openproject/process' => 'worker-default')

      # Service gets only common labels
      service_labels = template.labels('Service/optest-openproject')
      expect(service_labels).to include('environment' => 'production')
      expect(service_labels).to include('team' => 'backend')
      expect(service_labels).not_to include('tier')
      expect(service_labels).not_to include('component')
      expect(service_labels).not_to include('custom-web-label')
      expect(service_labels).not_to include('custom-worker-label')
    end

    it 'applies correct annotations to each deployment type', :aggregate_failures do
      # Web deployment gets common + web-specific annotations
      web_annotations = template.annotations('Deployment/optest-openproject-web')
      expect(web_annotations).to include('monitoring.io/scrape' => 'true')
      expect(web_annotations).to include('custom.io/web-annotation' => 'web-specific-annotation')

      # Worker deployment gets common + worker-specific annotations
      worker_annotations = template.annotations('Deployment/optest-openproject-worker-default')
      expect(worker_annotations).to include('monitoring.io/scrape' => 'true')
      expect(worker_annotations).to include('custom.io/worker-annotation' => 'worker-specific-annotation')

      # Service gets only common annotations
      service_annotations = template.annotations('Service/optest-openproject')
      expect(service_annotations).to include('monitoring.io/scrape' => 'true')
      expect(service_annotations).not_to include('custom.io/web-annotation')
      expect(service_annotations).not_to include('custom.io/worker-annotation')
    end
  end

  context 'with additional OpenProject resources' do
    let(:default_values) do
      HelmTemplate.with_defaults(<<~YAML
        commonLabels:
          environment: staging
          team: backend
        commonAnnotations:
          monitoring.io/scrape: "true"
        seederJob:
          annotations:
            custom.io/seeder-annotation: "seeder-specific"
      YAML
      )
    end

    it 'applies common labels and annotations to all OpenProject resources', :aggregate_failures do
      # Test web deployment
      web_labels = template.labels('Deployment/optest-openproject-web')
      web_annotations = template.annotations('Deployment/optest-openproject-web')
      expect(web_labels).to include('environment' => 'staging')
      expect(web_labels).to include('team' => 'backend')
      expect(web_annotations).to include('monitoring.io/scrape' => 'true')

      # Test worker deployment
      worker_labels = template.labels('Deployment/optest-openproject-worker-default')
      worker_annotations = template.annotations('Deployment/optest-openproject-worker-default')
      expect(worker_labels).to include('environment' => 'staging')
      expect(worker_labels).to include('team' => 'backend')
      expect(worker_annotations).to include('monitoring.io/scrape' => 'true')

      # Test service
      service_labels = template.labels('Service/optest-openproject')
      service_annotations = template.annotations('Service/optest-openproject')
      expect(service_labels).to include('environment' => 'staging')
      expect(service_labels).to include('team' => 'backend')
      expect(service_annotations).to include('monitoring.io/scrape' => 'true')

      # Test ingress
      ingress_labels = template.labels('Ingress/optest-openproject')
      ingress_annotations = template.annotations('Ingress/optest-openproject')
      expect(ingress_labels).to include('environment' => 'staging')
      expect(ingress_labels).to include('team' => 'backend')
      expect(ingress_annotations).to include('monitoring.io/scrape' => 'true')

      # Test PVC
      pvc_labels = template.labels('PersistentVolumeClaim/optest-openproject')
      expect(pvc_labels).to include('environment' => 'staging')
      expect(pvc_labels).to include('team' => 'backend')

      # Test ServiceAccount
      sa_labels = template.labels('ServiceAccount/optest-openproject')
      expect(sa_labels).to include('environment' => 'staging')
      expect(sa_labels).to include('team' => 'backend')
    end
  end

  context 'edge cases' do
    context 'with empty commonLabels and commonAnnotations' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          commonLabels: {}
          commonAnnotations: {}
        YAML
        )
      end

      it 'does not break with empty values' do
        web_labels = template.labels('Deployment/optest-openproject-web')
        expect(web_labels).to include('app.kubernetes.io/name' => 'openproject')
        expect(web_labels).to include('openproject/process' => 'web')

        web_annotations = template.annotations('Deployment/optest-openproject-web')
        expect(web_annotations).to be_nil
      end
    end

    context 'with nil commonLabels and commonAnnotations' do
      let(:default_values) do
        HelmTemplate.with_defaults(<<~YAML
          commonLabels: null
          commonAnnotations: null
        YAML
        )
      end

      it 'handles nil values gracefully' do
        web_labels = template.labels('Deployment/optest-openproject-web')
        expect(web_labels).to include('app.kubernetes.io/name' => 'openproject')
        expect(web_labels).to include('openproject/process' => 'web')

        web_annotations = template.annotations('Deployment/optest-openproject-web')
        expect(web_annotations).to be_nil
      end
    end
  end
end
