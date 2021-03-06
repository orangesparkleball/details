class OrganizationsController < ApplicationController
  skip_before_filter :load_project
  before_filter :load_organization, :only => [:show, :edit, :update, :projects, :delete, :destroy]
  before_filter :load_page_title, :only => [:show, :members, :projects, :edit, :update, :delete]
  before_filter :redirect_community, :only => [:index, :new, :create]

  def index
    @page_title = t('organizations.index.title')
    @organizations = current_user.organizations
  end

  def show
    # redirect_to edit_organization_path(@organization)
    @projects = @organization.projects
    @pending_projects = current_user.invitations.pending_projects
    @new_conversation = Conversation.new(:simple => true)
    @activities = Activity.for_projects(@projects)
    @threads = @activities.threads
    @last_activity = @threads.all.last
    @archived_projects = @organization.projects.archived
    @commentable_projects = @projects.select { |p| p.commentable?(current_user) and not p.archived? }
    
    respond_to do |f|
      f.html
      f.m     { redirect_to activities_path if request.path == '/' }
      f.rss   { render :layout  => false }
      f.xml   { render :xml     => @projects.to_xml }
      f.json  { render :as_json => @projects.to_xml }
      f.yaml  { render :as_yaml => @projects.to_xml }
      f.ics   { render :text    => Project.to_ical(@projects, params[:filter] == 'mine' ? current_user : nil, request.host, request.port) }
      f.print { render :layout  => 'print' }
    end
  end

  def members
    @users_not_belonging_to_org = @organization.external_users
  end

  def projects
    @people = current_user.people
    @roles = {  Person::ROLES[:observer] =>    t('roles.observer'),
                Person::ROLES[:commenter] =>   t('roles.commenter'),
                Person::ROLES[:participant] => t('roles.participant'),
                Person::ROLES[:admin] =>       t('roles.admin') }
  end

  def new
    @organization = current_user.organizations.build
  end

  def create
    @organization = Organization.new(params[:organization])

    if @organization.save
      membership = @organization.memberships.build(:role => Membership::ROLES[:admin])
      membership.user_id = current_user.id
      membership.save!
      flash[:notice] = t('organizations.new.created')
      redirect_to organization_path(@organization)
    else
      flash.now[:error] = t('organizations.new.invalid_organization')
      render :new
    end
    
  end
  
  def edit
  end

  def update
    if @organization.update_attributes(params[:organization])
      flash.now[:success] = t('organizations.edit.saved')
    end
    render :edit
  end

  def external_view
    @organization = Organization.find_by_permalink(params[:id])
  end

  def delete
    if !@organization.is_admin? current_user
      flash[:error] = t('organizations.delete.need_to_be_admin')
      redirect_to @organization
    end
  end

  def destroy
    if !@organization.is_admin? current_user
      flash[:error] = t('organizations.delete.need_to_be_admin')
      redirect_to @organization
    elsif @organization.projects.any?
      flash[:error] = t('organizations.delete.not_with_projects')
      redirect_to @organization
    else
      @organization.destroy
      flash[:notice] = t('organizations.delete.deleted')
      redirect_to organizations_path
    end
  end

  protected

    def load_organization
      unless @organization = current_user.organizations.find_by_permalink(params[:id])
        if organization = Organization.find_by_permalink(params[:id])
          redirect_to external_view_organization_path(@organization)
        else
          flash[:error] = t('organizations.edit.invalid')
          redirect_to root_path
        end
      end
    end

    def load_page_title
      @page_title = h(@organization)
    end

    def redirect_community
      if Teambox.config.community
        flash[:error] = t('organizations.not_in_community')
        redirect_to root_path
      end
    end

end
