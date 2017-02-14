require 'spec_helper'

RSpec.describe CatarseMoip::NotificationDecorator do
  let(:notification_instance) { double(:notification) }
  let(:notification) { CatarseMoip::NotificationDecorator.decorate(notification_instance) }

  describe "#deliver_process_notification" do
    subject { notification.deliver_process_notification }

    context "when the notification responds to deliver_process_notification" do
      let(:result) { double(:result) }

      before do
        allow(notification_instance).to receive(:deliver_process_notification).and_return(result)
      end

      it { is_expected.to eq(result) }
    end

    context "when the notification does not respond to deliver_process_notification" do
      it { is_expected.to be_nil }
    end
  end

  describe "#deliver_slip_canceled_notification" do
    subject { notification.deliver_slip_canceled_notification }

    context "when the notification responds to deliver_slip_canceled_notification" do
      let(:result) { double(:result) }

      before do
        allow(notification_instance).to receive(:deliver_slip_canceled_notification).and_return(result)
      end

      it { is_expected.to eq(result) }
    end

    context "when the notification does not respond to deliver_slip_canceled_notification" do
      it { is_expected.to be_nil }
    end
  end
end
