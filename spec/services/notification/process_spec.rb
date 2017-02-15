require 'spec_helper'

describe Notification::Process do

  let(:contribution) { create(:contribution) }
  let(:params_status_payment)      { payment_statuses[:started_status] }
  let(:params_cod_moip)            { 1000 }
  let(:params_valor)               { 59000 }
  let(:params_cancellation_reason) { nil }
  let(:payment_statuses) do
    {
      authorized_status:     1,
      started_status:        2,
      printed_boleto_status: 3,
      finished_status:       4,
      canceled_status:       5,
      process_status:        6,
      written_back_status:   7,
      refunded_status:       9
    }
  end
  let(:params) do
    {
      id_transacao:     1,
      status_pagamento: params_status_payment,
      cod_moip:         params_cod_moip,
      valor:            params_valor,
      classificacao:    params_cancellation_reason
    }
  end
  let(:payment_notification) { double('PaymentNotification') }

  describe ".call" do
    subject { Notification::Process.call(params) }

    context "when the payment is found" do

      before do
        allow(PaymentEngines).to receive(:find_payment).and_return(contribution)
      end

      context "and it is successfully processed" do
        before do
          allow(contribution).to receive(:notify_payment).and_return(payment_notification)
          allow(contribution).to receive(:transaction).and_yield
          allow(contribution).to receive(:update)
        end

        context "when the payment is payable" do
          before do
            allow(contribution).to receive(:paid?).and_return(false)
            allow(contribution).to receive(:pay!)

            subject
          end

          [:finished_status, :authorized_status].each do |status|
            context "and the status is '#{status}'" do
              let(:params_status_payment) { payment_statuses[status] }

              it "updates the payment to 'pay' status" do
                expect(contribution).to have_received(:pay!)
              end
            end
          end
        end

        context "when the payment is refundable" do
          before do
            allow(contribution).to receive(:refunded?).and_return(false)
            allow(contribution).to receive(:refund!)

            subject
          end

          [:written_back_status, :refunded_status].each do |status|
            context "and the status is '#{status}'" do
              let(:params_status_payment) { payment_statuses[status] }

              it "updates the payment to 'refund' status" do
                expect(contribution).to have_received(:refund!)
              end
            end
          end
        end

        context "when the payment status is 'canceled'" do
          let(:params_status_payment) { payment_statuses[:canceled_status] }
          let(:params_cancellation_reason) { "Dados Inválidos" }

          before do
            allow(contribution).to receive(:refused?).and_return(false)
            allow(contribution).to receive(:refuse!)
            allow(contribution).to receive(:update_cancellation_reason).with(params_cancellation_reason)
          end

          context "and it is slip payment" do
            before do
              allow(contribution).to receive(:slip_payment?).and_return(true)
              allow(payment_notification).to receive(:deliver_slip_canceled_notification)
              
              subject
            end

            it "updates the payment to 'refuse' status" do
              expect(contribution).to have_received(:refuse!)
            end

            it "updates the payment cancellation reason" do
              expect(contribution).to have_received(:update_cancellation_reason)
                                                  .with(params_cancellation_reason)
            end

            it "notifies that a slip payment is canceled" do
              expect(payment_notification).to have_received(:deliver_slip_canceled_notification)
            end
          end

          context "and it is not slip payment" do
            before do
              allow(contribution).to receive(:slip_payment?).and_return(false)

              subject
            end

            it "updates the payment to 'refuse' status" do
              expect(contribution).to have_received(:refuse!)
            end

            it "updates the payment cancellation reason" do
              expect(contribution).to have_received(:update_cancellation_reason)
                                                  .with(params_cancellation_reason)
            end
          end
        end

        context "when the payment status is 'processed'" do
          let(:params_status_payment) { payment_statuses[:process_status] }

          before do
            allow(payment_notification).to receive(:deliver_process_notification)

            subject
          end

          it "notifies that the payment is in process" do
            expect(payment_notification).to have_received(:deliver_process_notification)
          end
        end
      end

      context "when gateway_id is greater than params' cod_moip" do
        let(:contribution) { create(:contribution, gateway_id: '120.110.12') }
        let(:params_cod_moip) { '12' }

        before do
          allow(PaymentEngines).to receive(:find_payment).and_return(contribution)
          allow(contribution).to receive(:notify_payment).and_return(payment_notification)
          allow(contribution).to receive(:transaction).and_yield
        end

        context "and the payment is invalid" do
          context "and the params' valor is nil" do
            let(:params_valor) { nil }

            it { is_expected.to be_nil }
          end

          context "and the params' valor is not nil" do
            context "and the params' valor is greater than payment's value" do
              let(:params_valor) { 5000 }
              let(:contribution) { create(:contribution, value: 10) }

              it { is_expected.to be_nil }
            end
          end
        end
      end
    end

    context "when payment is not found" do
      before do
        allow(PaymentEngines).to receive(:find_payment).and_return(nil)
      end

      it { is_expected.to be_nil }
    end
  end
end
