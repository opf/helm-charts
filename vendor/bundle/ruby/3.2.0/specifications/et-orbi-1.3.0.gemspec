# -*- encoding: utf-8 -*-
# stub: et-orbi 1.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "et-orbi".freeze
  s.version = "1.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/floraison/et-orbi/issues", "changelog_uri" => "https://github.com/floraison/et-orbi/blob/master/CHANGELOG.md", "documentation_uri" => "https://github.com/floraison/et-orbi", "homepage_uri" => "https://github.com/floraison/et-orbi", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/floraison/et-orbi" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["John Mettraux".freeze]
  s.date = "2025-08-08"
  s.description = "Time zones for fugit and rufus-scheduler. Urbi et Orbi.".freeze
  s.email = ["jmettraux+flor@gmail.com".freeze]
  s.homepage = "https://github.com/floraison/et-orbi".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "time with zones".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<tzinfo>.freeze, [">= 0"])
  s.add_development_dependency(%q<ostruct>.freeze, [">= 0"])
  s.add_development_dependency(%q<probatio>.freeze, ["~> 1.3"])
  s.add_development_dependency(%q<chronic>.freeze, ["~> 0.10"])
end
