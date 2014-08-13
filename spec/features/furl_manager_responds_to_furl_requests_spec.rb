require 'rails_helper'
require 'gds_api/test_helpers/publishing_api'

feature "fURL manager responds to fURL requets" do
  include GdsApi::TestHelpers::PublishingApi
  include PublishingApiHelper

  background do
    stub_default_publishing_api_put
    create :furl_request, from_path: "/ministry-of-beards",
                          to_path: "/government/organisations/ministry-of-beards",
                          reason: "Because we really need to think about beards",
                          contact_email: "gandalf@example.com",
                          created_at: Time.zone.parse("2014-01-01 12:00:00"),
                          organisation_title: "Ministry of Beards"
    login_as create(:user, permissions: ['signon', 'manage_furls'])
  end

  scenario "fURL manager accepts a fURL request, and a redirect is created" do
    visit furl_requests_path

    click_on "Ministry of Beards"
    click_on "Accept and create redirect"

    expect(page).to have_content("The redirect has been published")

    expect(Redirect.count).to eql 1

    assert_publishing_api_put_item('/ministry-of-beards', publishing_api_redirect_hash("/ministry-of-beards", "/government/organisations/ministry-of-beards"))

    expect(ActionMailer::Base.deliveries.count).to eql 1
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eql ['gandalf@example.com']
    expect(mail.subject).to include 'Friendly URL request approved'
  end

  scenario "fURL manager rejects a fURL request, giving a reason" do
    visit furl_requests_path

    click_on "Ministry of Beards"
    click_on "Reject"
    fill_in "Reason", with: "Beards are soo last season."
    click_on "Reject"

    expect(page).to have_content("The friendly URL request has been rejected, and the requester has been notified")

    expect(ActionMailer::Base.deliveries.count).to eql 1
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eql ['gandalf@example.com']
    expect(mail.subject).to include 'Friendly URL request denied'
    expect(mail).to have_body_content "Beards are soo last season."
  end
end