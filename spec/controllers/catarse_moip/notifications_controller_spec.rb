require 'spec_helper'

describe CatarseMoip::NotificationsController, type: :controller do

  describe "POST #create_notification" do
    before do
      allow(CatarseMoip::Notification::Process).to receive(:call)

      post :create_notification, id: 10, locale: :pt, use_route: 'catarse_moip'
    end

    it { expect(response).to have_http_status(200) }

    it { expect(response).to render_template(nil) }
  end
end
