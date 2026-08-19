require "json"
require "pathname"
require "securerandom"
require "time"

module RailsProof
  class ReviewStore
    attr_reader :root

    def initialize(root:)
      @root = Pathname.new(root)
    end

    def save(
      concern:,
      test_output:,
      test_file_path:,
      test_class_name:,
      target_path: nil
    )
      review_directory.mkpath

      path = review_directory.join(
        review_filename(
          test_class_name: test_class_name,
          name: concern[:name] || concern["name"]
        )
      )

      path.write(
        JSON.pretty_generate(
          review_record(
            concern: concern,
            test_output: test_output,
            test_file_path: test_file_path,
            test_class_name: test_class_name,
            target_path: target_path
          )
        ) + "\n"
      )

      path
    end

    private

    def review_directory
      root.join(".rails_proof/review")
    end

    def review_filename(test_class_name:, name:)
      timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%S")
      slug = slugify("#{test_class_name}-#{name}")
      token = SecureRandom.hex(4)

      "#{timestamp}-#{slug}-#{token}.json"
    end

    def slugify(value)
      value
        .to_s
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/\A-+|-+\z/, "")
        .slice(0, 80)
    end

    def review_record(
      concern:,
      test_output:,
      test_file_path:,
      test_class_name:,
      target_path:
    )
      {
        version: 1,
        status: "needs_review",
        created_at: Time.now.utc.iso8601,
        target_path: target_path,
        test_file_path: test_file_path,
        test_class_name: test_class_name,
        name: concern[:name] || concern["name"],
        reason: concern[:reason] || concern["reason"],
        test_code: concern[:test_code] || concern["test_code"],
        test_output: test_output
      }
    end
  end
end