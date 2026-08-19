require "test_helper"
require "fileutils"
require "rails_proof/target_discovery"

class RailsProof::TargetDiscoveryTest < ActiveSupport::TestCase
  setup do
    @root = Rails.root.join("tmp/rails_proof_target_discovery")

    FileUtils.rm_rf(@root)
    FileUtils.mkdir_p(@root)
  end

  teardown do
    FileUtils.rm_rf(@root)
  end

  test "discovers one model file" do
    create_file "app/models/post.rb"

    target = discover("app/models/post.rb").first

    assert_equal :model, target.type
    assert_equal "app/models/post.rb", target.path
    assert_equal "Post", target.class_name
  end

  test "discovers a namespaced controller file" do
    create_file "app/controllers/admin/posts_controller.rb"

    target = discover("app/controllers/admin/posts_controller.rb").first

    assert_equal :controller, target.type
    assert_equal "app/controllers/admin/posts_controller.rb", target.path
    assert_equal "Admin::PostsController", target.class_name
  end

  test "discovers all models in a directory" do
    create_file "app/models/application_record.rb"
    create_file "app/models/post.rb"
    create_file "app/models/user.rb"
    create_file "app/models/admin/account.rb"
    create_file "app/models/concerns/searchable.rb"

    targets = discover("app/models")

    assert_equal(
      [
        "app/models/admin/account.rb",
        "app/models/post.rb",
        "app/models/user.rb"
      ],
      targets.map(&:path)
    )

    assert targets.all? { |target| target.type == :model }
  end

  test "discovers all controllers in a directory" do
    create_file "app/controllers/application_controller.rb"
    create_file "app/controllers/posts_controller.rb"
    create_file "app/controllers/admin/users_controller.rb"
    create_file "app/controllers/concerns/authentication.rb"

    targets = discover("app/controllers")

    assert_equal(
      [
        "app/controllers/admin/users_controller.rb",
        "app/controllers/posts_controller.rb"
      ],
      targets.map(&:path)
    )

    assert targets.all? { |target| target.type == :controller }
  end

  test "discovers models and controllers when no scope is given" do
    create_file "app/models/application_record.rb"
    create_file "app/models/post.rb"
    create_file "app/controllers/application_controller.rb"
    create_file "app/controllers/posts_controller.rb"

    targets = discover

    assert_equal(
      [
        [:model, "app/models/post.rb"],
        [:controller, "app/controllers/posts_controller.rb"]
      ],
      targets.map { |target| [target.type, target.path] }
    )
  end

  test "rejects unsupported Rails directories" do
    create_file "app/jobs/report_job.rb"

    error = assert_raises ArgumentError do
      discover("app/jobs")
    end

    assert_equal "Unsupported RailsProof target: app/jobs", error.message
  end

  test "rejects missing targets" do
    error = assert_raises ArgumentError do
      discover("app/models/missing.rb")
    end

    assert_equal(
      "RailsProof target not found: app/models/missing.rb",
      error.message
    )
  end

  test "rejects paths outside the Rails application" do
    error = assert_raises ArgumentError do
      discover("../somewhere")
    end

    assert_equal(
      "RailsProof scope must stay inside the Rails application",
      error.message
    )
  end

  private

  def discover(scope = nil)
    RailsProof::TargetDiscovery.new(
      root: @root,
      scope: scope
    ).targets
  end

  def create_file(relative_path)
    path = @root.join(relative_path)

    FileUtils.mkdir_p(path.dirname)
    File.write(path, "# fixture\n")
  end
end