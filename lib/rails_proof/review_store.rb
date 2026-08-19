require "digest"
require "json"
require "pathname"
require "securerandom"
require "time"
require "rails_proof/ai_test_identity"

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

      timestamp = Time.now.utc.iso8601
      fingerprint = target_fingerprint(target_path)

      existing_path = find_existing_review(
        concern: concern,
        target_path: target_path,
        test_file_path: test_file_path,
        target_fingerprint: fingerprint
      )

      if existing_path
        update_existing_review(
          path: existing_path,
          concern: concern,
          test_output: test_output,
          timestamp: timestamp
        )

        return existing_path
      end

      path = review_directory.join(
        review_filename(
          test_class_name: test_class_name,
          name: concern_name(concern)
        )
      )

      path.write(
        JSON.pretty_generate(
          review_record(
            concern: concern,
            test_output: test_output,
            test_file_path: test_file_path,
            test_class_name: test_class_name,
            target_path: target_path,
            target_fingerprint: fingerprint,
            timestamp: timestamp
          )
        ) + "\n"
      )

      path
    end

    def outstanding_findings(
      target_path:,
      test_file_path:
    )
      fingerprint = target_fingerprint(target_path)

      return [] unless fingerprint

      review_paths.filter_map do |path|
        record = read_record(path)

        next unless record
        next unless record["status"] == "needs_review"
        next unless record["target_path"] == target_path
        next unless record["test_file_path"] == test_file_path
        next unless record["target_fingerprint"] == fingerprint

        record
      end
    end

    private

    def review_directory
      root.join(".rails_proof/review")
    end

    def review_paths
      return [] unless review_directory.directory?

      review_directory.glob("*.json")
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
      target_path:,
      target_fingerprint:,
      timestamp:
    )
      {
        version: 3,
        status: "needs_review",
        created_at: timestamp,
        last_seen_at: timestamp,
        occurrences: 1,
        target_path: target_path,
        target_fingerprint: target_fingerprint,
        test_file_path: test_file_path,
        test_class_name: test_class_name,
        kind: concern_kind(concern),
        name: concern_name(concern),
        reason: concern_reason(concern),
        test_code: concern_test_code(concern),
        test_fingerprint:
          RailsProof::AiTestIdentity.test_fingerprint(
            concern_test_code(concern)
          ),
        test_output: test_output
      }
    end

    def update_existing_review(
      path:,
      concern:,
      test_output:,
      timestamp:
    )
      record = read_record(path)

      return unless record

      record["last_seen_at"] = timestamp
      record["occurrences"] =
        record.fetch("occurrences", 1).to_i + 1
      record["kind"] = concern_kind(concern)
      record["name"] = concern_name(concern)
      record["reason"] = concern_reason(concern)
      record["test_code"] = concern_test_code(concern)
      record["test_fingerprint"] =
        RailsProof::AiTestIdentity.test_fingerprint(
          concern_test_code(concern)
        )
      record["test_output"] = test_output

      path.write(
        JSON.pretty_generate(record) + "\n"
      )
    end

    def find_existing_review(
      concern:,
      target_path:,
      test_file_path:,
      target_fingerprint:
    )
      return nil unless target_fingerprint

      review_paths.find do |path|
        record = read_record(path)

        next false unless record
        next false unless record["status"] == "needs_review"
        next false unless record["target_path"] == target_path
        next false unless record["test_file_path"] == test_file_path
        next false unless(
          record["target_fingerprint"] == target_fingerprint
        )

        RailsProof::AiTestIdentity.same?(
          first_name: concern_name(concern),
          first_test_code: concern_test_code(concern),
          second_name: record["name"],
          second_test_code: record["test_code"]
        )
      end
    end

    def concern_name(concern)
      concern[:name] || concern["name"]
    end

    def concern_reason(concern)
      concern[:reason] || concern["reason"]
    end

    def concern_test_code(concern)
      concern[:test_code] || concern["test_code"]
    end

    def target_fingerprint(target_path)
      return nil if target_path.blank?

      path = root.join(target_path)

      return nil unless path.file?

      Digest::SHA256.hexdigest(path.read)
    end

    def concern_kind(concern)
      kind = concern[:kind] || concern["kind"]

      kind&.to_s
    end

    def read_record(path)
      JSON.parse(path.read)
    rescue JSON::ParserError, Errno::ENOENT
      nil
    end
  end
end