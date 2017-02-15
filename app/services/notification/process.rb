require 'enumerate_it'

class Notification::Process
  class TransactionStatus < ::EnumerateIt::Base
    associate_values(
      authorized:     1,
      started:        2,
      printed_boleto: 3,
      finished:       4,
      canceled:       5,
      process:        6,
      written_back:   7,
      refunded:       9
    )
  end

  def initialize(params)
    @params = params
  end

  def self.call(params)
    new(params).call
  end

  def call
    process_moip_message unless payment.nil?
  end

  private
  attr_accessor :params

  def payment
    @payment ||= find_payment
  end

  def find_payment
    payment = PaymentEngines.find_payment(key: params[:id_transacao])
    CatarseMoip::PaymentEngineDecorator.decorate(payment) unless payment.nil?
  end

  def process_moip_message
    payment.transaction do
      notification
      process_payment
    end
  end

  def notification
    @notification ||= CatarseMoip::NotificationDecorator.decorate(payment.notify_payment(extra_data: parse_params))
  end

  def process_payment
    return if !update_payment_id? && invalid_payment?

    update_payment_status(params[:status_pagamento].to_i)
  end

  def update_payment_id?
    return if payment.payment_id > params[:cod_moip].to_i

    payment.update(payment_id: params[:cod_moip])
  end

  def invalid_payment?
    params[:valor].present? && (params[:valor].to_i/100.0) < payment.value
  end

  def update_payment_status(payment_status)
    case payment_status
    when TransactionStatus::PROCESS
      notification.deliver_process_notification
    when TransactionStatus::AUTHORIZED, TransactionStatus::FINISHED
      payment.pay! unless payment.paid?
    when TransactionStatus::WRITTEN_BACK, TransactionStatus::REFUNDED
      payment.refund! unless payment.refunded?
    when TransactionStatus::CANCELED
      cancel_payment unless payment.refused?
    end
  end

  def cancel_payment
    payment.refuse!
    payment.update_cancellation_reason(params[:classificacao])
    notification.deliver_slip_canceled_notification if payment.slip_payment?
  end

  def parse_params
    JSON.parse(params.to_json.force_encoding('iso-8859-1').encode('utf-8'))
  end
end
