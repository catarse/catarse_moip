class CatarseMoip::PaymentEngineDecorator < Draper::Decorator
  delegate_all

  def notify_payment(extra_data: extra_data)
    if object.respond_to?(:notify_payment)
      object.notify_payment(extra_data: extra_data)
    else
      CatarseMoip::Notification.new
    end
  rescue ArgumentError
    CatarseMoip::Notification.new
  end

  def update_cancellation_reason(reason)
    object.update_cancellation_reason(reason) if object.respond_to?(:update_cancellation_reason)
  end

  def payment_id
    @payment_id ||= object.gateway_id.gsub('.', '').to_i
  rescue Exception
    0
  end
end
