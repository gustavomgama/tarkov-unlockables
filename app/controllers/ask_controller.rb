# frozen_string_literal: true

# Natural-language front door. Ask::Resolver retrieves the candidates in code
# and lets Jev pick one; the answer is composed from the record, so the model
# never states a fact.
class AskController < ApplicationController
  # Test seam: a fake Jev client keeps the request specs off the network.
  class_attribute :jev_client, default: nil

  def show
    @question = params[:q].to_s.strip
    return if @question.empty?

    @answer = Ask::Resolver.call(@question, client: self.class.jev_client)
  end
end
