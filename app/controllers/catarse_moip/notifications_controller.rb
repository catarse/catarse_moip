require 'moip_transparente'

module CatarseMoip
  class NotificationsController < ApplicationController
    skip_before_filter :force_http
    layout :false

    def create_notification
      Notification::Process.call(params)
      return render :nothing => true, :status => 200
    end
  end
end
