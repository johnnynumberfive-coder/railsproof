# RailsProof

> **You write the Rails app. We write the tests.**

RailsProof analyzes a Rails application, discovers behavior that should be tested, writes ordinary Minitest tests, and verifies generated tests against the application before deciding what to keep.

It combines two approaches:

1. **Deterministic Rails inspection** for behavior RailsProof can identify with confidence.
2. **AI-assisted analysis** for application-specific behavior that a fixed rule engine cannot reasonably anticipate.

RailsProof is being developed for modern Rails applications, with current development targeting **Rails 8.1+** and **Ruby 4.0+**.

> **Status: Early development**
>
> RailsProof is under active development ahead of its first public release. Its behavior and public API may change. Use version control when trying it on real applications.

Need help, found something weird, or just want to talk about RailsProof?

**Visit us at https://support.oakharborventures.com**

---

## What RailsProof Does

Given a model like:

```ruby
class Post < ApplicationRecord
  belongs_to :user

  validates :title, presence: true

  def title_matches?(query)
    return false if query.blank?

    title.to_s.downcase.include?(query.to_s.downcase)
  end
end
```

RailsProof can deterministically identify:

```text
belongs_to :user
validates presence of title
```

It can then use AI to analyze custom application behavior and discover useful coverage such as:

```text
title_matches? returns false for blank queries
title_matches? performs a case insensitive substring match
title_matches? returns false when the query is absent from the title
title_matches? handles a nil title
```

RailsProof generates candidate Minitest code, validates it, inserts one candidate at a time, and runs the actual Rails test suite against that candidate.

A candidate that passes can become permanent coverage.

A candidate that fails is **not automatically assumed to be wrong**.

That distinction matters.

A failing generated test may mean:

- the generated test is incorrect
- the application contains a bug
- the test exposed a contract mismatch
- the application and candidate simply disagree about intended behavior

RailsProof preserves that distinction instead of silently throwing useful evidence away.

---

## Quick Start

Run RailsProof against the entire supported application:

```bash
rails generate rails_proof:test
```

Inspect a specific model:

```bash
rails generate rails_proof:test app/models/post.rb
```

Inspect all models:

```bash
rails generate rails_proof:test app/models
```

Inspect a controller:

```bash
rails generate rails_proof:test app/controllers/posts_controller.rb
```

Or inspect all controllers:

```bash
rails generate rails_proof:test app/controllers
```

There is no separate AI mode and no `--ai` flag.

AI analysis is part of the normal RailsProof workflow.

---

## How It Works

RailsProof deliberately does not hand unrestricted control of your test files to an AI model.

The workflow looks like this:

```text
Rails application
      |
      v
Target discovery
      |
      v
Rails runtime/source inspection
      |
      v
Deterministic test planning
      |
      v
Existing test analysis
      |
      v
AI behavior analysis
      |
      v
Deterministic AI deduplication
      |
      v
Candidate Minitest generation
      |
      v
Syntax and structure validation
      |
      v
Insert one candidate
      |
      v
Run the actual test
      |
      +---- PASS -----------------> KEPT
      |
      +---- FAIL -----------------> restore live test file
                                     |
                                     v
                                NEEDS REVIEW
                                     |
                                     v
                           persist review evidence
```

Malformed or unusable generated tests are:

```text
REJECTED
```

Tests already covered, duplicated in the same AI response, or already represented by an unresolved review finding are:

```text
SKIPPED
```

RailsProof owns the file mutation, validation, execution, rollback, review storage, and deduplication process.

AI supplies analysis and candidate tests.

The Rails test runner determines whether a candidate agrees with the application as it currently exists.

The developer remains responsible for deciding whether a disagreement represents an application bug or an incorrect expectation.

---

## Result States

AI-generated candidate tests currently have four possible outcomes.

### KEPT

```text
KEPT: title_matches? handles a nil title
```

The candidate was structurally valid and passed against the application.

RailsProof leaves the test in the live test suite.

A passing test proves that the candidate expectation is compatible with the current implementation. It does not, by itself, prove that the implementation is correct.

### NEEDS REVIEW

```text
NEEDS REVIEW: title_matches_exactly? rejects partial title matches
  candidate test failed against application
  Review saved: .rails_proof/review/...
```

The candidate was structurally valid but failed against the application.

RailsProof:

1. restores the live test file to its previous state
2. preserves the candidate test
3. preserves the reason it was generated
4. preserves the test-run failure output
5. records the finding for human review

A failing valid test is evidence of a disagreement, not proof that the generated test is bad.

### REJECTED

```text
REJECTED: malformed generated test
  test code is not valid Ruby
```

The generated candidate itself is unusable.

Examples include:

- invalid Ruby
- missing or multiple test declarations
- class declarations inside the candidate
- `require` statements
- Markdown code fences
- other structurally invalid generated output

Rejected tests are not preserved as application-bug findings because RailsProof could not establish that they were valid candidate tests.

### SKIPPED

```text
SKIPPED: title_matches_exactly? requires the whole title to match
  already awaiting human review
```

RailsProof determined that executing the candidate would add no useful new information.

Current skip reasons include:

```text
already exists in test suite
already awaiting human review
duplicate AI suggestion
```

---

## Contract Checks

RailsProof does not assume that the current implementation is automatically the intended contract.

This is especially important for AI-assisted testing.

Consider:

```ruby
def title_matches_exactly?(query)
  return false if query.blank?

  title.to_s.downcase.include?(query.to_s.downcase)
end
```

The method is named:

```text
title_matches_exactly?
```

but its implementation performs a substring match with:

```ruby
include?
```

A test generator that blindly treats implementation as specification might generate tests proving that partial matches succeed and permanently encode the bug into the test suite.

RailsProof's AI protocol distinguishes two kinds of suggestions.

### coverage

A `coverage` suggestion tests behavior where the implementation and apparent contract agree.

For example:

```text
title_matches? returns false for blank queries
```

### contract_check

A `contract_check` is used when strong evidence in the source suggests that the apparent public contract and implementation disagree.

For example:

```text
title_matches_exactly? rejects partial title matches
```

RailsProof may generate:

```ruby
test "title_matches_exactly? rejects partial title matches" do
  post = Post.new(title: "Learning Rails")

  assert_not post.title_matches_exactly?("Rails")
end
```

If the implementation uses `include?`, that test fails.

RailsProof does not delete the evidence and does not leave the failing test in the live suite.

It produces:

```text
NEEDS REVIEW
```

That gives the developer a concrete test, a reason, and the actual failure output to evaluate.

---

## Human Review

RailsProof treats failing valid generated tests differently from malformed generated tests.

That distinction is intentional.

Suppose RailsProof finds:

```text
Method: title_matches_exactly?
Implementation: include?
```

and generates a test requiring a full-title match.

If the test fails, RailsProof cannot safely conclude:

```text
the AI was wrong
```

It also cannot safely conclude:

```text
the application is wrong
```

Instead it records:

```text
application behavior and candidate expectation disagree
```

and asks for human judgment.

Review findings are currently stored beneath:

```text
.rails_proof/review/
```

A review record contains information such as:

```text
status
created_at
last_seen_at
occurrences
target_path
target_fingerprint
test_file_path
test_class_name
kind
name
reason
test_code
test_fingerprint
test_output
```

The review workflow is still evolving, but the underlying evidence is already preserved rather than discarded.

---

## Review Deduplication and Convergence

AI output is nondeterministic.

The same underlying behavior might be described differently on separate runs:

```text
title_matches_exactly? requires a case-insensitive full-title match
```

then:

```text
title_matches_exactly? requires the entire title to match
```

then:

```text
title_matches_exactly? rejects partial title matches
```

RailsProof does not rely only on those human-readable names to determine identity.

Its deterministic deduplication layer examines candidate behavior so differently worded suggestions can still be recognized as the same underlying finding.

That means repeated runs against unchanged source converge instead of endlessly creating duplicate tests or duplicate review findings.

For an unresolved finding:

```text
first run
  -> NEEDS REVIEW
  -> review evidence stored

later run against unchanged source
  -> same underlying behavior recognized
  -> SKIPPED
  -> already awaiting human review
```

RailsProof also fingerprints the target source associated with a review finding.

If the application source changes, an old review finding no longer automatically suppresses new testing.

```text
unchanged source + same finding
  -> SKIPPED

changed source
  -> eligible for analysis and execution again
```

This allows a natural development loop:

```text
RailsProof discovers disagreement
        |
        v
NEEDS REVIEW
        |
        v
developer evaluates finding
        |
        v
application code changes
        |
        v
source fingerprint changes
        |
        v
RailsProof analyzes behavior again
        |
        v
candidate passes
        |
        v
KEPT
```

---

## Setup-Sensitive Deduplication

Two tests can contain the same assertion without testing the same behavior.

For example:

```ruby
post = Post.new(title: "Learning Rails")

assert_not post.title_matches_exactly?("Rails")
```

and:

```ruby
post = Post.new(title: nil)

assert_not post.title_matches_exactly?("Rails")
```

have the same assertion text but different setup and therefore test different behavior.

RailsProof's AI deduplication accounts for setup context when comparing meaningful candidate behavior.

This prevents an important class of false-positive deduplication where legitimate coverage could otherwise be silently discarded.

RailsProof therefore aims to be conservative about skipping tests:

```text
same assertion + different setup
  != same behavior
```

---

## Example

A normal successful RailsProof run can look like:

```text
RailsProof targets: 1
RailsProof inspection
Model file: app/models/post.rb
Model class: Post
Test file: test/models/post_test.rb
Test status: exists
Test cases: 7

Source associations: 1
  belongs_to :user

Source validations: 1
  validates :title, presence: true

Runtime inspection: available
Table: posts

Suggested tests: 2
  belongs_to :user
  validates presence of title

Coverage:
  Covered: 2
  Missing: 0

AI suggested tests: 3
  title_matches? returns false for blank queries
  title_matches? performs a case insensitive substring match
  title_matches? handles a nil title

AI test results: 3
  KEPT: title_matches? returns false for blank queries
  KEPT: title_matches? performs a case insensitive substring match
  KEPT: title_matches? handles a nil title
```

A run that discovers a possible application bug can look like:

```text
AI suggested tests: 1
  title_matches_exactly? rejects partial title matches
    Reason: The method name strongly indicates equality semantics,
    while the implementation performs substring matching.

AI test results: 1
  NEEDS REVIEW: title_matches_exactly? rejects partial title matches
    candidate test failed against application
    Review saved: .rails_proof/review/...
```

Running RailsProof again without changing the application can then produce:

```text
AI test results: 1
  SKIPPED: title_matches_exactly? requires the whole title to match
    already awaiting human review
```

even though the AI described the finding differently.

---

## Deterministic Analysis

RailsProof first handles the parts of a Rails application that can be understood without AI.

### Models

Current deterministic model inspection includes:

- Active Record columns
- associations
- presence validations
- existing Minitest tests
- missing deterministic coverage

For example:

```ruby
class Post < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
end
```

can produce:

```ruby
test "belongs to user" do
  association = Post.reflect_on_association(:user)

  assert_not_nil association
  assert_equal :belongs_to, association.macro
end

test "validates presence of title" do
  record = Post.new(title: nil)

  record.validate

  assert record.errors.of_kind?(:title, :blank)
end
```

RailsProof also avoids separately generating the implicit presence validation Rails adds for a required `belongs_to` association.

### Controllers

RailsProof currently understands controller actions and their matching routes.

For example:

```ruby
class PostsController < ApplicationController
  def index
  end

  def show
  end
end
```

with matching routes can produce:

```ruby
test "should get index" do
  get posts_index_url

  assert_response :success
end

test "should get show" do
  get posts_show_url

  assert_response :success
end
```

Existing Rails-generated controller tests are recognized so RailsProof does not needlessly recreate them.

---

## Existing Tests

RailsProof is designed to work with an existing test suite rather than assume it is starting from scratch.

It currently recognizes:

- Rails-style `test "..." do` declarations
- method-style `def test_...` declarations

Existing tests are used for both deterministic and AI-assisted analysis.

RailsProof can:

- compare deterministic concerns against existing tests
- insert only missing deterministic tests
- provide existing tests to AI as context
- avoid AI tests already represented in the live suite
- preserve passing generated tests across later candidate failures
- avoid repeated AI suggestions within the same run
- avoid repeatedly executing unresolved review findings

RailsProof is intended to be run repeatedly as an application evolves, not merely once when the project is created.

---

## AI Analysis

Fixed rules can only take automatic test generation so far.

Consider:

```ruby
def eligible_for_upgrade?
  active? && account_age_days > 30 && !past_due?
end
```

or:

```ruby
def cancel!
  transaction do
    update!(status: :cancelled)
    subscription&.cancel!
    CancellationMailer.confirmation(self).deliver_later
  end
end
```

There is no general Rails reflection API that can determine every meaningful behavioral test for application-specific code like this.

That is where RailsProof uses AI.

The AI receives structured context including:

- target type
- class name
- application source
- existing tests
- deterministic concerns already discovered by RailsProof

It is instructed to avoid duplicating behavior already covered by deterministic analysis or existing tests.

It is also instructed not to assume that current implementation behavior is necessarily the intended public contract.

The AI returns structured suggestions containing:

- suggestion kind
- test name
- reason
- candidate Minitest code

Supported suggestion kinds currently include:

```text
coverage
contract_check
```

RailsProof independently validates, deduplicates, writes, and executes the returned candidate code.

The AI does not directly control application test files.

---

## AI Safety

Generated code is not blindly accepted.

Before an AI-generated test can execute, RailsProof currently checks that the candidate:

- is nonblank
- parses as valid Ruby
- contains exactly one Minitest test declaration
- does not contain a class declaration
- does not contain a `require` statement
- does not contain Markdown code fences

Candidates are evaluated one at a time.

Before each candidate, RailsProof captures the previous state of the test file.

If the candidate passes, it may remain in the suite.

If it fails, the previous file state is restored.

That means:

```text
candidate 1 passes
  -> kept

candidate 2 fails
  -> rolled back

candidate 1 remains
```

A later failure does not discard earlier successful coverage.

---

## Why a Passing Generated Test Is Not Enough

A generated test can pass and still be a bad test.

For example, if RailsProof sees:

```ruby
def title_matches_exactly?(query)
  title.include?(query)
end
```

and generates:

```ruby
assert post.title_matches_exactly?("Rails")
```

for a title of:

```text
Learning Rails
```

the test passes.

But it may simply be locking an implementation bug into the suite.

That is why RailsProof distinguishes normal coverage from contract checks and why application behavior is not treated as unquestionable specification.

The goal is not:

```text
generate tests that make the current code pass
```

The goal is:

```text
generate meaningful tests for the application's apparent contract
and surface disagreements that deserve human attention
```

---

## Installation

RailsProof is currently under active development and has not yet reached its first public release.

For development from a local checkout, add RailsProof to the application's `Gemfile`:

```ruby
gem "rails_proof", path: "../railsproof"
```

Then run:

```bash
bundle install
```

After the public release, installation will be:

```ruby
gem "rails_proof"
```

followed by:

```bash
bundle install
```

The planned first public release is **RailsProof 1.0.0**.

---

## AI Provider Setup

RailsProof's core AI interface is provider-agnostic.

The first implemented provider adapter uses OpenAI.

Applications using the OpenAI adapter currently need the OpenAI Ruby SDK available:

```ruby
gem "openai"
```

Then run:

```bash
bundle install
```

Set your API key through the environment:

```bash
export OPENAI_API_KEY="your-key-here"
```

Do not commit API keys to your repository.

RailsProof currently defaults to:

```text
gpt-5.6
```

The model can be overridden with:

```bash
export RAILSPROOF_OPENAI_MODEL="your-model"
```

AI usage is performed using your provider credentials and may incur charges from that provider.

RailsProof's own test suite does not require paid AI calls. Development tests use a fake AI client.

---

## Running RailsProof

### Entire supported application

```bash
rails generate rails_proof:test
```

### One model

```bash
rails generate rails_proof:test app/models/post.rb
```

### All models

```bash
rails generate rails_proof:test app/models
```

### One controller

```bash
rails generate rails_proof:test app/controllers/posts_controller.rb
```

### All controllers

```bash
rails generate rails_proof:test app/controllers
```

RailsProof currently discovers supported targets beneath:

```text
app/models
app/controllers
```

Base framework files and concern directories are ignored.

---

## Generated Tests

RailsProof generates ordinary Minitest tests.

A generated model test looks like normal Rails code:

```ruby
class PostTest < ActiveSupport::TestCase
end
```

Controller tests use:

```ruby
class PostsControllerTest < ActionDispatch::IntegrationTest
end
```

There is no RailsProof-specific runtime DSL inside generated tests.

After a test is kept, developers can:

- read it
- edit it
- move it
- run it directly
- maintain it like any other Rails test

The generated suite remains a normal Rails test suite.

---

## Why Minitest?

RailsProof currently targets the test framework Rails ships with by default:

**Minitest.**

The goal is not to create a RailsProof-specific testing framework.

The goal is to produce tests a Rails developer already understands.

That also keeps generated coverage useful even if RailsProof itself is later removed from the application.

---

## Current Limitations

RailsProof is still young.

Current limitations include:

- deterministic model analysis covers only a subset of Rails validations and behaviors
- deterministic controller analysis currently focuses primarily on routed response behavior
- AI behavior identity is intentionally conservative and will continue to evolve as more real-world cases are discovered
- generated tests can still contain logically incorrect expectations
- complex setup may require more application context than RailsProof currently supplies
- the human review workflow currently persists findings but does not yet provide a complete review-management command
- review findings do not yet have a full accepted/rejected/resolved lifecycle
- jobs, mailers, services, channels, system tests, and other Rails components are not yet first-class targets
- OpenAI is currently the first implemented AI provider adapter
- configuration is still minimal
- APIs and generated output may change as RailsProof evolves

Use Git and review generated changes.

---

## Roadmap

Near-term development includes:

- human review commands and workflow
- review resolution states
- retrying or accepting saved review candidates
- richer existing-test analysis
- additional model validations and associations
- deeper controller behavior analysis
- improved context gathering for application-specific code
- generated-test failure analysis and repair
- regression detection when previously passing generated tests begin failing
- jobs
- mailers
- service objects
- additional Rails components
- additional AI providers
- provider configuration
- improved command output and reporting

Deterministic AI suggestion deduplication and source-aware convergence are already implemented.

The long-term goal is straightforward:

> Point RailsProof at a Rails application and let it continuously build and maintain meaningful test coverage as the application evolves.

---

## Development

Clone the repository and install dependencies:

```bash
bundle install
```

Run the RailsProof test suite:

```bash
bin/test
```

Individual tests can also be run directly:

```bash
bin/test test/rails_proof/model_inspector_test.rb
```

RailsProof includes a dummy Rails application under:

```text
test/dummy
```

which is used for integration testing against real Rails models, controllers, routes, generated tests, AI candidate execution, rollback, review persistence, and convergence behavior.

Dummy application tests can be run explicitly, for example:

```bash
bin/test test/dummy/test/models/post_test.rb
```

---

## Testing Philosophy

RailsProof itself is tested against both deterministic fixtures and deliberately tricky AI-generation scenarios.

Important behavior is tested at multiple layers:

```text
unit behavior
     |
     v
filter / executor behavior
     |
     v
generator integration
     |
     v
real dummy Rails application
```

The dummy application is useful for deliberately introducing plausible bugs and verifying the complete RailsProof lifecycle.

For example:

```text
introduce implementation bug
        |
        v
run RailsProof
        |
        v
contract check generated
        |
        v
candidate fails
        |
        v
NEEDS REVIEW
        |
        v
run RailsProof again
        |
        v
same finding recognized
        |
        v
SKIPPED
        |
        v
fix application
        |
        v
source fingerprint changes
        |
        v
RailsProof analyzes again
        |
        v
passing coverage KEPT
```

The intent is to test RailsProof against the messy cases produced by real nondeterministic AI output, not only idealized fixtures.

---

## Support

Questions about RailsProof? Something not working? Found behavior you aren't sure is a bug?

**Visit https://support.oakharborventures.com**

Ask a question, report a problem, tell us what RailsProof got wrong, or just come talk to us about what you're building.

We'd much rather hear from you than have you spend an afternoon fighting with RailsProof by yourself.

---

## Contributing

RailsProof is in active development, and bug reports, test cases, design discussion, and pull requests are welcome.

For changes to test generation or deduplication behavior, please include tests demonstrating both:

- behavior that RailsProof should recognize as equivalent
- behavior that RailsProof must keep distinct

False-positive deduplication is especially important to avoid because silently skipping legitimate coverage is worse than generating an occasional duplicate.

Because RailsProof can modify application test files, changes involving generation, AI output, validation, execution, rollback, review persistence, or deduplication should be treated carefully and tested thoroughly.

---

## Philosophy

RailsProof is not intended to replace developers or make test design invisible.

It is intended to eliminate the repetitive part of keeping a Rails application tested while still producing ordinary, understandable test code.

Rails already knows a tremendous amount about an application.

AI can reason about behavior that Rails cannot describe through reflection alone.

The test runner can determine whether a generated expectation agrees with the current implementation.

Deterministic safeguards can prevent nondeterministic AI output from repeatedly creating the same work.

Human review can resolve the cases where implementation and apparent contract disagree.

RailsProof brings those pieces together.

The principle is simple:

```text
Do not blindly trust the AI.
Do not blindly trust the implementation.
Do not throw away useful disagreements.
Do not generate the same work forever.
```

**You write the Rails app. We write the tests.**

---

## License

RailsProof is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).