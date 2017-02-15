require 'spec_helper'

RSpec.describe CatarseMoip::PaymentEngineDecorator do
  let(:contribution)   { create(:contribution) }
  let(:payment_engine) { CatarseMoip::PaymentEngineDecorator.decorate(contribution) }

  describe "#notify_payment" do
    subject { payment_engine.notify_payment(extra_data: {}) }

    context "when the contribution responds to notify_payment" do
      context "and the method gets expected params" do
        let(:notification_instance) { double(:notification) }

        before do
          allow(contribution).to receive(:notify_payment).with(extra_data: {}).and_return(notification_instance)
        end

        it { is_expected.to eq(notification_instance) }
      end

      context "and the method gets unexpected params" do
        before do
          allow(contribution).to receive(:notify_payment).with(extra_data: {}).and_raise(ArgumentError)
        end

        it { is_expected.to be_a_kind_of(CatarseMoip::Notification) }
      end
    end

    context "when the contribution does not respond to notify_payment" do
      it { is_expected.to be_a_kind_of(CatarseMoip::Notification) }
    end
  end

  describe "#update_cancellation_reason" do
    subject { payment_engine.update_cancellation_reason("reason") }

    context "when the contribution responds to update_cancellation_reason" do
      let(:notification_instance) { double(:notification) }

      before do
        allow(contribution).to receive(:update_cancellation_reason).with("reason").and_return(notification_instance)
      end

      it { is_expected.to eq(notification_instance) }
    end

    context "when the contribution does not respond to update_cancellation_reason" do
      it { is_expected.to be_nil }
    end
  end

  describe "#payment_id" do
    subject { payment_engine.payment_id }

    context "when a exception is not thrown" do
      let(:contribution) { create(:contribution, gateway_id: '00.10.30') }

      it { is_expected.to eq(1030) }
    end

    context "when a exception is thrown" do
      before do
        allow(contribution).to receive(:gateway_id).and_raise(Exception)
      end

      it { is_expected.to be_zero }
    end
  end
end
