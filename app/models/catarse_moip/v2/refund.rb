module CatarseMoip
  module V2
    class Refund
      include ::HTTParty

      base_uri ::MOIP_V2_ENDPOINT

      attr_accessor :payment, :refund_options

      def self.start(payment)
        _instance = new(payment)
        _instance.refund
      end

      def initialize(payment)
        self.payment = payment
        self.refund_options = define_refund_options
      end

      def refund
        self.class.post("/v2/payments/#{parsed_payment_id}/refunds", {
          body: self.refund_options.to_json
        }.merge!(basic_auth_params))
      end

      def define_refund_options
        if refund_method == 'BANK_ACCOUNT'
          check_bank_account!
          {
            amount: amount_to_refund,
            method: refund_method,
            refundingInstrument: refund_instrument
          }
        else
          {}
        end
      end

      protected

      def check_bank_account!
        unless bank_account.valid?
          raise "Invalid bank account"
        end
      end

      def refund_instrument
        {
          method: refund_method,
          bankAccount: {
            type: 'CHECKING',
            bankNumber: bank_account.bank_code,
            agencyNumber: bank_account.agency.to_i,
            agencyCheckNumber: bank_account.agency_digit.to_i,
            accountNumber: bank_account.account.to_i,
            accountCheckNumber: bank_account.account_digit.to_i,
            holder: {
              fullname: bank_account.owner_name,
              taxDocument: {
                type: bank_account_document_type,
                number: parsed_holder_document
              }
            }
          }
        }
      end

      def bank_account
        self.payment.user.bank_account
      end

      def bank_account_document_type
        if parsed_holder_document.size > 11
          'CNPJ'
        else
          'CPF'
        end
      end

      def parsed_holder_document
        bank_account.owner_document.gsub(/[\.\-\/\s]/,'')
      end

      def amount_to_refund
        if already_expired_refund_deadline?
          ((self.payment.value - self.payment.gateway_fee.to_f) * 100).to_i
        else
          (self.payment.value * 100).round
        end
      end

      def refund_method
        if already_expired_refund_deadline? || !self.payment.is_credit_card?
          'BANK_ACCOUNT'
        else
          'CREDIT_CARD'
        end
      end

      def already_expired_refund_deadline?
        self.payment.paid_at < 170.days.ago
      end

      def basic_auth_params
        {
          basic_auth: {
            username: PaymentEngines.configuration[:moip_token],
            password:  PaymentEngines.configuration[:moip_key],
          },
          headers: {
            'Content-Type' => 'application/json'
          }
        }
      end

      def parsed_payment_id
        payment.gateway_id.gsub('.', '')
      end
    end
  end
end
