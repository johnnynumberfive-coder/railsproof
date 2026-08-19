# RailsProof

> **You write the Rails app. We write the tests.**

RailsProof analyzes a Rails application, discovers behavior that should be tested, writes Minitest tests, and verifies generated tests against the application before keeping them.

It combines two approaches:

1. **Deterministic Rails inspection** for behavior RailsProof can identify with certainty.
2. **AI-assisted analysis** for application-specific behavior that a fixed rule engine cannot reasonably anticipate.

RailsProof is being developed for modern Rails applications, with current development targeting **Rails 8.1+** and **Ruby 4.0+**.

> **Status: Early development**
>
> RailsProof is under active development. Its behavior and public API may change. Use version control when trying it on real applications.

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

It can then use AI to analyze the custom application behavior and discover additional useful coverage such as:

```text
title_matches? returns false for blank queries
title_matches? performs a case insensitive substring match
title_matches? returns false when the query is absent from the title
title_matches? handles a nil title
```

RailsProof generates candidate Minitest code for those behaviors, validates it, inserts each candidate individually, and runs the test.

A passing candidate is kept.

A failing candidate is rolled back.

---

## Quick Start

Run RailsProof against the entire supported application:

```bash
rails generate rails_proof:test
```

Or inspect a specific model:

```bash
rails generate rails_proof:test app/models/post.rb
```

A directory:

```bash
rails generate rails_proof:test app/models
```

Or controllers:

```bash
rails generate rails_proof:test app/controllers
```

There is no separate AI mode or special flag to remember. AI analysis is part of the normal RailsProof workflow.

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
      +---- PASS ----> keep the test
      |
      +---- FAIL ----> restore the previous file
```

RailsProof owns the files and execution process.

AI supplies reasoning and candidate tests.

The Rails test runner gets the final vote.

---

## Example

A RailsProof run currently looks something like:

```text
RailsProof targets: 1
RailsProof inspection
Model file: app/models/post.rb
Model class: Post
Test file: test/models/post_test.rb
Test status: exists
Test cases: 2

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

AI suggested tests: 4
  title_matches? returns false for blank queries
  title_matches? performs a case insensitive substring match
  title_matches? returns false when the query is absent from the title
  title_matches? handles a nil title

AI test results: 4
  KEPT: title_matches? returns false for blank queries
  KEPT: title_matches? performs a case insensitive substring match
  KEPT: title_matches? returns false when the query is absent from the title
  KEPT: title_matches? handles a nil title
```

The resulting test file contains ordinary Minitest code. There is no RailsProof-specific runtime required for the generated tests themselves.

---

## Deterministic Analysis

RailsProof first handles the parts of a Rails application that can be understood without AI.

Current deterministic support includes:

### Models

RailsProof can inspect:

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

can produce tests such as:

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

## AI Analysis

Fixed rules can only take test generation so far.

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

There is no general Rails reflection API that can determine every meaningful behavioral test for code like this.

That is where RailsProof uses AI.

The AI receives structured context including:

- target type
- class name
- application source
- existing tests
- deterministic concerns already discovered by RailsProof

It is explicitly instructed not to duplicate behavior already covered by deterministic analysis or existing tests.

The AI returns structured test suggestions containing:

- a test name
- the reason the behavior deserves coverage
- candidate Minitest code

RailsProof then independently validates and executes that code.

---

## AI Safety

Generated code is not blindly accepted.

Before an AI-generated test can be kept, RailsProof currently checks that the candidate:

- is nonblank
- parses as valid Ruby
- contains exactly one Minitest test declaration
- does not contain a class declaration
- does not contain a `require` statement
- does not contain Markdown code fences

RailsProof then inserts the candidate and runs the actual test.

If it passes:

```text
KEPT: title_matches? handles a nil title
```

the candidate remains in the test file.

If it fails:

```text
REJECTED: some generated behavior
  generated test failed
```

RailsProof restores the file to its previous state.

Candidates are evaluated one at a time, so a later failed test does not discard earlier candidates that have already passed.

---

## Installation

RailsProof is currently under active development and has not reached a stable public release.

For development from a local checkout, add RailsProof to the application's `Gemfile`:

```ruby
gem "rails_proof", path: "../railsproof"
```

Then run:

```bash
bundle install
```

A normal packaged installation will eventually be:

```ruby
gem "rails_proof"
```

followed by:

```bash
bundle install
```

---

## AI Provider Setup

RailsProof's core AI interface is provider-agnostic.

The first implemented provider adapter uses OpenAI.

At the moment, applications using the OpenAI adapter must also have the OpenAI Ruby SDK available:

```ruby
gem "openai"
```

Then:

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

## Existing Tests

RailsProof is designed to work with an existing test suite rather than assume it is starting from scratch.

It can:

- detect existing Minitest test cases
- recognize Rails-style `test "..." do` declarations
- recognize method-style `def test_...` declarations
- compare existing tests against deterministic concerns
- insert only missing deterministic tests
- provide existing tests to AI as context
- preserve passing AI-generated tests across candidate failures

RailsProof should be usable repeatedly during development, not just once when a project is created.

---

## Why Minitest?

RailsProof currently targets the test framework Rails ships with by default:

**Minitest.**

Generated tests are ordinary Rails tests:

```ruby
class PostTest < ActiveSupport::TestCase
end
```

and:

```ruby
class PostsControllerTest < ActionDispatch::IntegrationTest
end
```

The goal is to generate tests a Rails developer can read, edit, run, and maintain normally.

---

## Current Limitations

RailsProof is still young.

Current limitations include:

- deterministic model analysis covers only a subset of Rails validations and behaviors
- deterministic controller coverage currently focuses on routed response behavior
- AI coverage deduplication and convergence still need stronger deterministic safeguards
- AI-generated tests can still be incorrect even when syntactically valid
- complex setup may require more application context than RailsProof currently supplies
- jobs, mailers, services, channels, system tests, and other Rails components are not yet first-class targets
- OpenAI is currently the first implemented AI provider adapter
- configuration is still minimal
- APIs and generated output may change significantly before the first stable release

Use Git and review generated changes.

---

## Roadmap

Near-term development includes:

- deterministic AI suggestion deduplication
- AI convergence controls
- richer existing-test analysis
- additional model validations and associations
- deeper controller behavior analysis
- improved context gathering for application-specific code
- generated-test failure analysis and repair
- jobs
- mailers
- service objects
- additional Rails components
- additional AI providers
- provider configuration
- improved command output and reporting

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

which is used for integration testing against real Rails models, controllers, routes, and generated tests.

---

## Contributing

RailsProof is in early development, but bug reports, test cases, design discussion, and pull requests are welcome.

For changes to test generation behavior, please include tests demonstrating both the intended behavior and the cases RailsProof should avoid.

Because RailsProof can modify application test files, changes involving generation, AI output, validation, execution, or rollback should be treated carefully and tested thoroughly.

---

## Philosophy

RailsProof is not intended to replace developers or make test design invisible.

It is intended to eliminate the repetitive part of keeping a Rails application tested while still producing ordinary, understandable test code.

Rails already knows a tremendous amount about an application.

AI can reason about the behavior Rails cannot describe through reflection alone.

The test runner can determine whether generated code actually works.

RailsProof brings those three pieces together.

**You write the Rails app. We write the tests.**

---

## License

RailsProof is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).