class InvitationsController < ApplicationController
  include EnforceUgoWorkspaceAccess

  before_action :load_workspace, except: [ :respond ]
  before_action :authorize_workspace_admin!, except: [ :respond ]
  before_action :ensure_ugo_workspace_active!, except: [ :respond ]
  before_action :load_invitation, only: [ :destroy ]

  def create
    @invitation = @workspace.invitations.new(invitation_params)
    @invitation.invited_by = Current.user
    @invitation.role = invitation_role

    if self_hosted? && !User.exists?(email: @invitation.email)
      create_and_add_user_to_workspace
      return
    end

    if @invitation.save
      InvitationMailer.with(invitation: @invitation).invite_email.deliver_later
      flash.now[:notice] = "Invitation sent to #{@invitation.email}"
    else
      flash.now[:alert] = @invitation.errors.full_messages.to_sentence
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to workspace_path(@workspace) }
    end
  end

  def destroy
    email = @invitation.email
    @invitation.destroy
    flash.now[:notice] = "Invitation to #{email} was cancelled"

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to workspace_path(@workspace) }
    end
  end

  # User responds to their own invitation (accept/decline)
  def respond
    @invitation = Invitation.pending.find_by(id: params[:id], email: Current.user.email)

    if @invitation.nil?
      flash.now[:alert] = "Invitation not found, expired, or already processed"
      render turbo_stream: turbo_stream.update("flash", partial: "shared/flash")
      return
    end

    if params[:response] == "accept"
      @invitation.accept!(Current.user)
      @workspace = @invitation.workspace
      flash.now[:notice] = "You've joined #{@workspace.name}"
    else
      @invitation.update!(accepted_at: Time.current)
      flash.now[:notice] = "Invitation declined"
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_path }
    end
  end

  private

  def create_and_add_user_to_workspace
    password = SecureRandom.hex(8)
    user = User.new(email: @invitation.email, password: password, password_confirmation: password)

    ActiveRecord::Base.transaction do
      user.save!
      @workspace.memberships.create!(user: user, role: invitation_role)
    end

    AdminMailer.user_created(user, password).deliver_later
    flash.now[:notice] = "User #{user.email} created and added as #{invitation_role}."

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to workspace_path(@workspace) }
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Failed to create user: #{e.message}"
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to workspace_path(@workspace) }
    end
  end

  def load_workspace
    @workspace = Current.user.workspaces.find_by(id: params[:workspace_id])
    redirect_to dashboard_path, notice: "Workspace not found" if @workspace.nil?
  end

  def load_invitation
    @invitation = @workspace.invitations.find_by(id: params[:id])
    redirect_to workspace_path(@workspace), alert: "Invitation not found" if @invitation.nil?
  end

  def invitation_params
    params.require(:invitation).permit(:email)
  end

  def invitation_role
    role = params.dig(:invitation, :role)
    Invitation.roles.keys.include?(role) ? role : "member"
  end
end
