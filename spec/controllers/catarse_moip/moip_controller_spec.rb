# encoding: utf-8
require 'spec_helper'

describe CatarseMoip::MoipController do
  subject{ response }

  let(:get_token_response){{:status=>:fail, :code=>"171", :message=>"TelefoneFixo do endereço deverá ser enviado obrigatorio", :id=>"201210192052439150000024698931"}}
  let(:backer){ double('backer', {
    id: 1, 
    key: 'backer key', 
    payment_id: 'payment id', 
    project: project, 
    pending?: false, 
    value: 10, 
    user: user, 
    payer_name: 'foo',
    payer_email: 'foo@bar.com',
    address_street: 'test',
    address_number: '123',
    address_complement: '123',
    address_neighbourhood: '123',
    address_city: '123',
    address_state: '123',
    address_zip_code: '123',
    address_phone_number: '123'
  }) }

  let(:user){ double('user', id: 1) }
  let(:project){ double('project', id: 1, name: 'test project') }
  let(:extra_data){ {"id_transacao"=>backer.key, "valor"=>"2190", "cod_moip"=>"12345123", "forma_pagamento"=>"1", "tipo_pagamento"=>"CartaoDeCredito", "email_consumidor"=>"some@email.com", "controller"=>"catarse_moip/payment/notifications", "action"=>"create"} }

  before do
    controller.stub(:current_user).and_return(user)
    ::MoipTransparente::Checkout.any_instance.stub(:get_token).and_return(get_token_response)
    ::MoipTransparente::Checkout.any_instance.stub(:moip_widget_tag).and_return('<div>')
    ::MoipTransparente::Checkout.any_instance.stub(:moip_javascript_tag).and_return('<script>')
    ::MoipTransparente::Checkout.any_instance.stub(:as_json).and_return('{}')
    PaymentEngines.stub(:find_payment).and_return(backer)
    PaymentEngines.stub(:create_payment_notification)
    backer.stub(:with_lock).and_yield
  end

  describe "POST create_notification" do
    context "when we search for a non-existant backer" do
      before do
        PaymentEngines.should_receive(:find_payment).with(key: "non-existant backer key").and_raise('error')
        post :create_notification, {:id_transacao => "non-existant backer key", :use_route => 'catarse_moip'}
      end

      its(:status){ should == 422 }
      its(:body){ should == "#<RuntimeError: error>: error recebemos: {\"id_transacao\"=>\"non-existant backer key\", \"controller\"=>\"catarse_moip/moip\", \"action\"=>\"create_notification\"}" }
    end

    context "when we seach for an existing backer" do
      before do
        PaymentEngines.should_receive(:find_payment).with(key: backer.key).and_return(backer)
        controller.should_receive(:process_moip_message).with({"id_transacao"=>backer.key, "controller"=>"catarse_moip/moip", "action"=>"create_notification"})
        post :create_notification, {:id_transacao => backer.key, :use_route => 'catarse_moip'}
      end

      its(:body){ should == ' ' }
      its(:status){ should == 200 }
      it("should assign backer"){ assigns(:backer).should == backer }
    end
  end

  describe "GET js" do
    let(:file){ double('js_file') }

    context "when the content of get_javascript_url raises an error" do
      before do
        controller.should_receive(:open).at_least(3).times.and_raise('error') 
        ->{
          get :js, locale: :pt, use_route: 'catarse_moip'
        }.should raise_error('error')
      end
      its(:status){ should == 200 }
    end

    context "when the content of get_javascript_url is read without errors" do
      before do
        controller.should_receive(:open).and_return(file) 
        file.should_receive(:set_encoding).and_return(file)
        file.should_receive(:read).and_return(file)
        file.should_receive(:encode).and_return('js content')
        get :js, locale: :pt, use_route: 'catarse_moip'
      end
      its(:status){ should == 200 }
      its(:body){ should == 'js content' }
    end
  end

  describe "POST moip_response" do
    let(:processor){ double('moip processor') }
    before do
      controller.should_receive(:process_moip_message)
      post :moip_response, id: backer.id, response: {StatusPagamento: 'Sucesso'}, use_route: 'catarse_moip'
    end

    its(:status){ should == 200 }
  end

  describe "POST get_moip_token" do
    before do
      post :get_moip_token, :id => backer.id, :use_route => 'catarse_moip'
    end

    its(:status){ should == 200 }
    its(:body){ should == "{\"get_token_response\":{\"status\":\"fail\",\"code\":\"171\",\"message\":\"TelefoneFixo do endereço deverá ser enviado obrigatorio\",\"id\":\"201210192052439150000024698931\"},\"moip\":\"{}\",\"widget_tag\":{\"tag_id\":\"MoipWidget\",\"token\":null,\"callback_success\":\"checkoutSuccessful\",\"callback_error\":\"checkoutFailure\"}}" }
  end

  describe "#update_backer" do
    before do
      controller.stub(:backer).and_return(backer)
      backer.stub(:payment_token).and_return('token')
    end

    context "with parameters containing CodigoMoIP and TaxaMoIP" do
      let(:payment){ {"Status" => "Autorizado","Codigo" => "0","CodigoRetorno" => "0","TaxaMoIP" => "1.54","StatusPagamento" => "Sucesso","CodigoMoIP" => "18093844","Mensagem" => "Requisição processada com sucesso","TotalPago" => "25.00","url" => "https => //www.moip.com.br/Instrucao.do?token=R2W0N123E005F2A911V6O2I0Y3S7M4J853H0S0F0T0D044T8F4H4E9G0I3W8"} }
      before do
        MoIP.should_not_receive(:query)
        backer.should_receive(:update_attributes).with({
          payment_id: payment["CodigoMoIP"],
          payment_choice: payment["FormaPagamento"],
          payment_service_fee: payment["TaxaMoIP"]
        })
      end
      it("should call update attributes but not call MoIP.query"){ controller.update_backer payment }
    end

    context "with no response from moip" do
      let(:moip_query_response) { nil }
      before do
        MoIP.should_receive(:query).with(backer.payment_token).and_return(moip_query_response)
        backer.should_not_receive(:update_attributes)
      end
      it("should never call update attributes"){ controller.update_backer }
    end

    context "with an incomplete transaction" do
      let(:moip_query_response) do
        {"ID"=>"201210191926185570000024694351", "Status"=>"Sucesso"}
      end
      before do
        MoIP.should_receive(:query).with(backer.payment_token).and_return(moip_query_response)
        backer.should_not_receive(:update_attributes)
      end
      it("should never call update attributes"){ controller.update_backer }
    end

    context "with a real data set that works for some cases" do
      let(:moip_query_response) do
        {"ID"=>"201210191926185570000024694351", "Status"=>"Sucesso", "Autorizacao"=>{"Pagador"=>{"Nome"=>"juliana.giopato@hotmail.com", "Email"=>"juliana.giopato@hotmail.com"}, "EnderecoCobranca"=>{"Logradouro"=>"Rua sócrates abraão ", "Numero"=>"16.0", "Complemento"=>"casa 19", "Bairro"=>"Campo Limpo", "CEP"=>"05782-470", "Cidade"=>"São Paulo", "Estado"=>"SP", "Pais"=>"BRA", "TelefoneFixo"=>"1184719963"}, "Recebedor"=>{"Nome"=>"Catarse", "Email"=>"financeiro@catarse.me"}, "Pagamento"=>[{"Data"=>"2012-10-17T13:06:07.000-03:00", "DataCredito"=>"2012-10-19T00:00:00.000-03:00", "TotalPago"=>"50.00", "TaxaParaPagador"=>"0.00", "TaxaMoIP"=>"1.34", "ValorLiquido"=>"48.66", "FormaPagamento"=>"BoletoBancario", "InstituicaoPagamento"=>"Bradesco", "Status"=>"Autorizado", "Parcela"=>{"TotalParcelas"=>"1"}, "CodigoMoIP"=>"0000.1325.5258"}, {"Data"=>"2012-10-17T13:05:49.000-03:00", "TotalPago"=>"50.00", "TaxaParaPagador"=>"0.00", "TaxaMoIP"=>"3.09", "ValorLiquido"=>"46.91", "FormaPagamento"=>"CartaoDebito", "InstituicaoPagamento"=>"Visa", "Status"=>"Iniciado", "Parcela"=>{"TotalParcelas"=>"1"}, "CodigoMoIP"=>"0000.1325.5248"}]}}
      end
      before do
        MoIP.should_receive(:query).with(backer.payment_token).and_return(moip_query_response)
        payment = moip_query_response["Autorizacao"]["Pagamento"].first
        backer.should_receive(:update_attributes).with({
          payment_id: payment["CodigoMoIP"],
          payment_choice: payment["FormaPagamento"],
          payment_service_fee: payment["TaxaMoIP"]
        })
      end
      it("should call update attributes"){ controller.update_backer }
    end
  end

  describe "#process_moip_message" do
    before do
      controller.stub(:backer).and_return(backer)
      backer.stub(:confirmed?).and_return(false)
      backer.stub(:confirm!)
      controller.stub(:update_backer)
    end

    context "when we already have the payment_id in backers table" do
      before do
        backer.stub(:payment_id).and_return('test')
        controller.should_not_receive(:update_backer)
      end

      it 'should never call update_backer' do
        controller.process_moip_message post_moip_params.merge!({:id_transacao => backer.key, :status_pagamento => CatarseMoip::MoipController::TransactionStatus::AUTHORIZED})
      end
    end

    context "when we still do not have the payment_id in backers table" do
      before do
        backer.stub(:payment_id).and_return(nil)
        controller.should_receive(:update_backer)
      end

      it 'should call update_backer on the processor' do
        controller.process_moip_message post_moip_params.merge!({:id_transacao => backer.key, :status_pagamento => CatarseMoip::MoipController::TransactionStatus::AUTHORIZED})
      end
    end

    context "when there is a written back request and backer is not refunded" do
      before do
        backer.stub(:refunded?).and_return(false)
        backer.should_receive(:refund!)
      end

      it 'should call refund!' do
        controller.process_moip_message post_moip_params.merge!({:id_transacao => backer.key, :status_pagamento => CatarseMoip::MoipController::TransactionStatus::WRITTEN_BACK})
      end
    end

    context "when there is an authorized request" do
      before do
        backer.should_receive(:confirm!)
      end

      it 'should call confirm!' do
        controller.process_moip_message post_moip_params.merge!({:id_transacao => backer.key, :status_pagamento => CatarseMoip::MoipController::TransactionStatus::AUTHORIZED})
      end
    end

    context "when there is a refund request" do
      before do
        backer.stub(:refunded?).and_return(false)
        backer.should_receive(:refund!)
      end

      it 'should mark refunded to true' do
        controller.process_moip_message post_moip_params.merge!({:id_transacao => backer.key, :status_pagamento => CatarseMoip::MoipController::TransactionStatus::REFUNDED})
      end
    end
  end
end
