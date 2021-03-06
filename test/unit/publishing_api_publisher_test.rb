require "test_helper"
require "gds_api/test_helpers/publishing_api_v2"

class PublishingAPIPublisherTest < ActiveSupport::TestCase
  include GdsApi::TestHelpers::PublishingApiV2

  context ".perform(edition_id)" do
    setup do
      @edition = FactoryGirl.create(:edition)
      @artefact = @edition.artefact
      @artefact.update_attributes(content_id: "vat-charities-id")

      stub_publishing_api_publish("vat-charities-id", "update_type" => "minor", "locale" => "en")
    end

    should "notify the publishing API of the published document and links" do
      PublishingAPIPublisher.new.perform(@edition.id)
      assert_publishing_api_publish("vat-charities-id", "update_type" => "minor", "locale" => "en")
    end
  end
end
