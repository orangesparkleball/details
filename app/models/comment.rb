class Comment < ActiveRecord::Base
  
  extend ActiveSupport::Memoizable
  
  acts_as_paranoid
  
  concerned_with :tasks, :finders, :conversions

  belongs_to :user, :with_deleted => true
  belongs_to :project
  belongs_to :target, :polymorphic => true, :counter_cache => true
  belongs_to :assigned, :class_name => 'Person', :with_deleted => true
  belongs_to :previous_assigned, :class_name => 'Person', :with_deleted => true
  
  has_many :likes, :dependent => :destroy
  has_many :like_users, :through => :likes, :source => :user
  
  def task_comment?
    self.target_type == "Task"
  end

  has_many :uploads
  accepts_nested_attributes_for :uploads, :allow_destroy => true,
    :reject_if => lambda { |upload| upload['asset'].blank? }

  attr_accessible :body, :status, :assigned, :hours, :human_hours, :billable,
                  :upload_ids, :uploads_attributes, :due_on

  named_scope :by_user, lambda { |user| { :conditions => {:user_id => user} } }
  named_scope :latest, :order => 'id DESC'

  # TODO: investigate how we can enable this and not break nested attributes
  # validates_presence_of :target_id, :user_id, :project_id
  
  validate_on_create :check_duplicate, :if => lambda { |c| c.target_id? and not c.hours? }
  validates_presence_of :body, :unless => lambda { |c| c.task_comment? or c.uploads.any? }

  # was before_create, but must happen before format_attributes
  before_save   :copy_ownership_from_target, :if => lambda { |c| c.new_record? and c.target_id? }
  after_create  :trigger_target_callbacks
  after_destroy :cleanup_activities, :cleanup_conversation

  # must happen after copy_ownership_from_target
  formats_attributes :body

  attr_accessor :activity

  def hours?
    hours and hours > 0
  end
  
  def build_like_string(current_user)
    return "" if(like_users == 0) 
    names = like_users.collect{|u| u.id == current_user.id ? nil : "@#{u.login}" }.compact.sort
    if like_users.include?(current_user)
      case names.size
      when 0
        "You like this."
      when 1
        "You and #{names.join('')} like this."
      else
        last = names.pop
        "You, #{names.join(', ')} and #{last} like this."
      end
    else
      case names.size
      when 1
        "#{names.join('')} likes this."
      else
        last = names.pop
        "#{names.join(', ')} and #{last} like this."
      end
    end
  end

  named_scope :with_hours, :conditions => 'hours > 0'

  alias_attribute :human_hours, :hours

  # Instead of using the float 'hours' field in a form, we use 'human_hours'
  # and we can take:
  # 7 (hours)
  # 7.5 (hours with decimals)
  # 7h (hours)
  # 30m (minutes => fractions of hours)
  # 2h 30m (hours and minutes => hours with decimals)
  # 2:30 (hours and minutes => hours with decimals)
  def human_hours=(duration)
    self.hours = if duration.blank?
      nil
    elsif duration =~ /(\d+)h[ ]*(\d+)m/i
      # 2h 15m
      $1.to_f + $2.to_f / 60
    elsif duration =~ /(\d+):(\d+)/
      # 2:15
      $1.to_f + $2.to_f / 60.0
    elsif duration =~ /(\d+)m/i
      # 20m
      $1.to_f / 60.0
    elsif duration =~ /(\d+)h/i
      # 3h
      $1.to_f
    else
      # old-style numeric format
      duration.to_f
    end
  end

  def duplicate_of?(another)
    [:body, :assigned_id, :status, :hours].all? { |prop|
      self.send(prop) == another.send(prop)
    }
  end

  def thread_id
    "#{target_type}_#{target_id}"
  end
  
  protected

  # don't allow two identical updates in a row
  #
  # FIXME: doesn't work with "simple" conversations because
  # they hijack `target` in a before_save callback
  def check_duplicate
    last_comment = target.comments.by_user(self.user_id).latest.first
    
    if last_comment and last_comment.duplicate_of? self
      errors.add :body, :duplicate
    end
  end
  
  def copy_ownership_from_target # before_create
    self.user_id ||= target.user_id
    self.project_id ||= target.project_id
  end

  def trigger_target_callbacks # after_create
    @activity = project.log_activity(self, 'create') if project_id?

    if target.respond_to?(:add_watchers)
      new_watchers = defined?(@mentioned) ? @mentioned.to_a : []
      new_watchers << self.user if self.user
      target.add_watchers new_watchers
    end
    
    if target.respond_to?(:updated_at)
      target.update_attribute :updated_at, self.created_at
    end
  end
  
  def cleanup_activities # after_destroy
    Activity.destroy_all :target_type => self.class.name, :target_id => self.id
  end
  
  def cleanup_conversation
    if self.target.class == Conversation
      @conversation = self.target
      @conversation.destroy if @conversation.simple and @conversation.comments.count == 0
    end
  end
end