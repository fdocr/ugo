class ApplicationMailer < ActionMailer::Base
  default from: "no-reply@fdo.cr"
  layout "mailer"
end
