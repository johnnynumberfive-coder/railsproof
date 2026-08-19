require "rails_proof/version"
require "rails_proof/railtie"
require "rails_proof/open_ai_client"

module RailsProof
  class << self
    attr_writer :ai_client

    def ai_client
      @ai_client ||= OpenAiClient.new
    end
  end
end
