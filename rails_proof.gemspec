require_relative "lib/rails_proof/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_proof"
  spec.version     = RailsProof::VERSION
  spec.authors     = [ "Oak Harbor Ventures, LLC" ]
  spec.email       = [ "john@oakharborventures.com" ]

  spec.summary =
    "AI-assisted Minitest generation for modern Rails applications."

  spec.description =
    "RailsProof analyzes Rails applications using deterministic Rails " \
    "inspection and AI-assisted reasoning, generates ordinary Minitest " \
    "tests, executes candidate tests against the application, and " \
    "preserves disagreements for human review. Get help, ask questions, " \
    "or talk to us at https://support.oakharborventures.com."

  spec.homepage =
    "https://support.oakharborventures.com"

  spec.license = "MIT"

  spec.required_ruby_version = ">= 4.0"

  spec.metadata["homepage_uri"] = spec.homepage

  spec.metadata["source_code_uri"] =
    "https://github.com/johnnynumberfive-coder/railsproof"

  spec.metadata["changelog_uri"] =
    "https://github.com/johnnynumberfive-coder/railsproof/blob/main/CHANGELOG.md"

  spec.metadata["bug_tracker_uri"] =
    "https://github.com/johnnynumberfive-coder/railsproof/issues"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir[
      "{app,config,db,lib}/**/*",
      "MIT-LICENSE",
      "README.md",
      "CHANGELOG.md",
      "Rakefile"
    ]
  end

  spec.add_dependency "rails", ">= 8.1.3.1", "< 9.0"
end