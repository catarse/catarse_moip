require 'enumerate_it'
require 'moip_transparente'

module CatarseMoip
  class NotificationsController < ApplicationController
    attr_accessor :payment

    class TransactionStatus < ::EnumerateIt::Base
      associate_values(
        :authorized =>      1,
        :started =>         2,
        :printed_boleto =>  3,
        :finished =>        4,
        :canceled =>        5,
        :process =>         6,
        :written_back =>    7,
        :refunded => 9
      )
    end

    skip_before_filter :force_http
    layout :false

    def create
      process_moip_message
      return render :nothing => true, :status => 200
    rescue Exception => e
      return render :text => "#{e.inspect}: #{e.message} recebemos: #{params}", :status => 422
    end

    def payment
      @payment ||= PaymentEngines.find_payment key: params[:id_transacao]
    end

    def process_moip_message
      payment.with_lock do
        payment_notification = payment.payment_notifications.create({
          contribution: payment.contribution,
          extra_data: JSON.parse(
            params.to_json.force_encoding('iso-8859-1').encode('utf-8'))
        })

        payment_id = (payment.gateway_id.gsub(".", "").to_i rescue 0)

        if payment_id <= params[:cod_moip].to_i
          payment.update_attributes payment_id: params[:cod_moip]

          if (params[:valor].to_i/100.0) < payment.value && params[:valor]
            #return payment.invalid! unless payment.invalid_payment?
            return
          end

          case params[:status_pagamento].to_i
          when TransactionStatus::PROCESS
            payment_notification.deliver_process_notification
          when TransactionStatus::AUTHORIZED, TransactionStatus::FINISHED
            payment.pay! unless payment.paid?
          when TransactionStatus::WRITTEN_BACK, TransactionStatus::REFUNDED
            payment.refund! unless payment.refunded?
          when TransactionStatus::CANCELED
            unless payment.refused?
              payment.refuse!
              if payment.slip_payment?
                payment_notification.deliver_slip_canceled_notification
              end
            end
          end
        end
      end
    end

  end
end
