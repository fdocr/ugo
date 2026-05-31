class AdminMailerPreview < ActionMailer::Preview
  def user_created
    user = User.first || User.new(email: "newuser@example.com")
    AdminMailer.user_created(user, "temp-password-abc123")
  end
end
