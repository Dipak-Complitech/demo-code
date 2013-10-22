require 'bcrypt'
class User < ActiveRecord::Base
  ## Modules ##
  include BCrypt

  ## Array ##
  SNAP_FROM  = %w(everyone my_friends)
  LOGIN_WITH = %w(facebook general)

  ## Associations ##
  has_many :authentication_tokens, dependent: :destroy
  has_many :friend_relationships, dependent: :destroy
  has_many :friends, through: :friend_relationships,
            source: :friend, :dependent => :destroy
  has_many :invitations, dependent: :destroy,
           class_name: 'FriendRelationship',
           foreign_key: 'friend_id'
  has_many :invitors, through: :invitations,
            source: :user, :dependent => :destroy
  
  has_many :snap_received, class_name: 'Snap', foreign_key: 'receiver_id'
  has_many :snap_sent, class_name: 'Snap', foreign_key: 'sender_id'
  
  has_many :snaps, class_name: 'Snap', foreign_key: 'receiver_id'
  has_many :receivers, through: :snaps, source: :receiver
  has_many :histories, :dependent => :destroy

  has_many :free_sms_responses


  ## Mass Assignment ##
  attr_accessible :email, :mobile,
                  :username, :password,
                  :password_confirmation,
                  :receive_notification,
                  :snap_from,
                  :facebook_twitter_id,
                  :login_with, :facebook_email, :device_id, :device_type, :reset_pword_token

  ## Virtual Attributes ##
  attr_accessor :password, :password_confirmation,:check_username_validation, :without_password


  ## Validations ##
  validates :email,
            presence: true

  validates :email,
            uniqueness: true,
            format: {with: /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i },
            if: proc {|u| u.email? }

  validates :username,
            presence: true,
            uniqueness: true,
            format: {with: /^[a-z0-9_.]{5,20}$/i, message: "should only contains small alphabets and letters or dot(.) or underscore(_)"},
            length: {in: 5..20},
            if: :validate_username?

  validates :password,
            presence: true,
            confirmation: true,
            length: {in: 8..50},
            if: :password_required?

  validates :mobile,
            numericality: {only_integers: true},
            allow_blank: true,
            allow_nil: true


  ## Callbacks ##
  before_save :encrypt_password

  ## Scope ##
  scope :with_email, lambda { |email| where("email = ?", email) }
  scope :with_username, lambda {|username| where("username = ?", username)}
  scope :with_email_or_username, lambda { |login| where("email = ? or username = ?",login, login) }
  scope :who_can_everyone, where("snap_from = ?", "everyone")
  scope :who_can_my_friends, where("snap_from = ?", "my_friends")
  scope :latest, -> { order("username desc") }
  scope :without_user, lambda{|user| user ? {:conditions => ["id != ?", user.id]} : {} }
  scope :get_user_device_ids,lambda { |device_id| where("device_id = ?", device_id) }

  ## Class Methods ##
  class << self
    def authenticate(login, password)
      return nil, "Username/Email and Password is required" if login.blank? && password.blank?
      return nil, "Username/Email is required" if login.blank?
      return nil, "Password is required" if password.blank?
      user = with_email_or_username(login).try(:first)
      if user
        if user.valid_password?(password)
          return user, ''
        else
          return nil, 'Password is invalid'
        end
      else
        return nil, "User not found with '#{login}' username/email"
      end
    end

    def register_with_social_media(token,email)
      user = FbGraph::User.me(token)
      u = User.find_by_email(email)
      u = User.new unless u.present?
      u.without_password = 1
      u.facebook_twitter_id = token
      u.login_with          = "facebook"
      u.mobile             = user.fetch.mobile_phone
      u.email               = user.fetch.email
      u.screen_name         = user.fetch.username
      u
    end
  end

  ## Instance Methods ##
  def password_required?
    if without_password == 1
      false
    else
      !persisted? || !password.nil? || !password_confirmation.nil?
    end
  end

  def valid_password?(password)
    self.encrypted_password == BCrypt::Engine.hash_secret(password, self.password_salt)
  end

  def create_token
    self.authentication_tokens.create_new_token
  end
  
  def check_duplicate_device_ids(device_id,user)
    @users=User.get_user_device_ids(device_id)
    @users.update_all("device_id = 'nil'")
    user.update_attributes(:device_id => device_id)
  end
  def friends_with_divider
    friends = friend_relationships.name_wise.limit(1000).group_by do |f|
      f.friend_name.chars.first
    end
    op_friends = []
    friends.each do |f|
      l = OpenStruct.new
      l.divider = f.first
      l.friends = f.second
      op_friends << l
    end
    op_friends
  end

  def friend_invite
    op_friends = []
    friends_with_divider_pending.each do |friend|
      o = OpenStruct.new
      o.id = friend.id
      o.user_id = friend.user_id
      o.friend_id = friend.friend_id
      o.friend_name = friend.friend_name
      o.original_name = friend.original_name
      o.is_block = friend.is_block
      o.status = friend.status
      o.divider = friend.friend_name.chars.first.humanize 
      op_friends << o
    end

    invitations.pending.each do |friend|
      o = OpenStruct.new
      o.id = friend.id
      o.user_id = friend.friend_id
      o.friend_id = friend.user_id
      o.friend_name = friend.user.username
      o.original_name = friend.original_name
      o.is_block = friend.is_block
      o.status = "Added you"
      o.divider = friend.user.username.chars.first.humanize if friend.status == "accepted"
      o.divider = friend.status unless friend.status == "accepted"
      op_friends << o
    end
    op_friends
  end

  def display_search_users_data(friends)
    op_friends = []
    friends.each do |friend|
      o = OpenStruct.new
      op_friends << o
      o.id = friend.id
      o.email = friend.email
      o.username = friend.username
      o.mobile = friend.mobile
      o.receive_notification = friend.receive_notification
      o.snap_from = friend.snap_from
      o.device_token = "true" if friend.device_id.present?
      o.device_token = "false" unless friend.device_id.present?
      o.divider = friend.username.chars.first.humanize
      o.friend_status = "friend" if self.friends.where('username = ?', friend.username).present?
      o.friend_status = "unfriend" unless self.friends.where('username = ?', friend.username).present?
    end
    op_friends
  end


  def is_everyone?
    self.snap_from.downcase == "everyone"
  end

  def is_my_friends?
    self.snap_from.downcase == "My Friends"
  end

  def total_send_snaps
    self.snap_sent.count
  end

  def total_received_snaps
    self.snap_received.count
  end

  def has_device_id_and_type?
    self.device_id.present? # && self.device_type.present?
  end

  def send_gcm_notification(user)
    GCM.send_notification([self.device_id], {:message => "You received snap from #{user}"},
                            :collapse_key => "New Snap",
                            :time_to_live => 3600,
                            :identity => :message_key)
  end



  def self.search(search)
    if search
      find(:all, :conditions => ['username LIKE ?', "%#{search}%"], :order => "username")
    else
      find(:all)
    end
  end

  def is_facebook_user?
    self.login_with.to_s == "facebook"
  end


  private

  def validate_username?
    (check_username_validation == 1)? true : false
  end

  def encrypt_password
    if password.present?
      self.password_salt = BCrypt::Engine.generate_salt
      self.encrypted_password = BCrypt::Engine.hash_secret(password, password_salt)
    end
  end
end