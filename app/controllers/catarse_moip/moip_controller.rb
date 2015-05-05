require 'enumerate_it'
require 'moip_transparente'

module CatarseMoip
  class MoipController < ApplicationController
    attr_accessor :contribution

    skip_before_filter :force_http
    layout :false

    def js
      tries = 0
      begin
        @moip = ::MoipTransparente::Checkout.new
        render :text => open(@moip.get_javascript_url).set_encoding('ISO-8859-1').read.encode('utf-8')
      rescue Exception => e
        tries += 1
        retry unless tries > 3
        raise e
      end
    end

    def review
      @moip = ::MoipTransparente::Checkout.new
    end

    def moip_response
      @contribution = PaymentEngines.find_payment id: params[:id], user_id: current_user.id
      first_update_contribution unless params[:response]['StatusPagamento'] == 'Falha'
      render nothing: true, status: 200
    end

    def get_moip_token
      @contribution = PaymentEngines.find_payment id: params[:id], user_id: current_user.id

      ::MoipTransparente::Config.test = (PaymentEngines.configuration[:moip_test] == 'true')
      ::MoipTransparente::Config.access_token = PaymentEngines.configuration[:moip_token]
      ::MoipTransparente::Config.access_key = PaymentEngines.configuration[:moip_key]

      @moip = ::MoipTransparente::Checkout.new

      invoice = {
        razao: "Apoio para o projeto '#{contribution.project.name}'",
        id: contribution.key,
        total: contribution.value.to_s,
        acrescimo: '0.00',
        desconto: '0.00',
        cliente: {
          id: contribution.user.id,
          nome: contribution.payer_name,
          email: contribution.payer_email,
          logradouro: "#{contribution.address_street}, #{contribution.address_number}",
          complemento: contribution.address_complement,
          bairro: contribution.address_neighbourhood,
          cidade: contribution.address_city,
          uf: contribution.address_state,
          cep: contribution.address_zip_code,
          telefone: contribution.address_phone_number
        }
      }

      response = @moip.get_token(invoice)

      session[:thank_you_id] = contribution.project.id

      contribution.update_column :payment_token, response[:token] if response and response[:token]

      render json: {
        get_token_response: response,
        moip: @moip,
        widget_tag: {
          tag_id: 'MoipWidget',
          token: response[:token],
          callback_success: 'checkoutSuccessful',
          callback_error: 'checkoutFailure'
        }
      }
    end

    def first_update_contribution
      response = ::MoIP.query(contribution.payment_token)
      if response && response["Autorizacao"]
        params = response["Autorizacao"]["Pagamento"]
        params = params.first unless params.respond_to?(:key)

        contribution.with_lock do
          if params["Status"] == "Autorizado"
            contribution.confirm!
          elsif contribution.pending?
            contribution.waiting!
          end

          contribution.update_attributes({
            :payment_id => params["CodigoMoIP"],
            :payment_choice => params["FormaPagamento"],
            :payment_method => 'MoIP',
            :payment_service_fee => params["TaxaMoIP"]
          }) if params
        end
      end
    end
  end
end
