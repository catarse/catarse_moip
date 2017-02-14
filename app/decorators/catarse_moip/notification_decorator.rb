class CatarseMoip::NotificationDecorator < Draper::Decorator
  delegate_all

  def deliver_process_notification
    object.deliver_process_notification if object.respond_to?(:deliver_process_notification)
  end

  def deliver_slip_canceled_notification
    object.deliver_slip_canceled_notification if object.respond_to?(:deliver_slip_canceled_notification)
  end
end
