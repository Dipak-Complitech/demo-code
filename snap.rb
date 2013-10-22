class Snap < ActiveRecord::Base
  
  ## Relationship ##
  belongs_to :receiver, class_name: 'User'
  belongs_to :sender, class_name: 'User'
  has_many   :histories, :as => :history, :dependent => :destroy

  attr_accessor :receiver_detail

  ## Mass Assignment ##
  attr_accessible :allow_sec, :receiver_delete, :receiver_id, :receiver_detail,
                  :sender_delete, :sender_id, :status, :avatar, :avatar_image,
                  :avatar_fname, :smsid

  
  ## Validations ##
  validates :allow_sec, :sender_id, presence: true
  validates :allow_sec, :inclusion => { :in => 1..10, :message => "%{value} is not a valid" }
  validates_attachment :avatar, :presence => true, :on => :create

  ## Attachments ##

  has_attached_file :avatar, 
    :path => "#{Rails.root.to_s}/public/snaps/:attachment/:id/:filename",
    :url => "/snaps/:attachment/:id/:filename"

  has_attached_file :avatar_image, 
    :path => "#{Rails.root.to_s}/public/snaps/:attachment/:id/:filename",
    :url => "/snaps/:attachment/:id/:filename"

  ## Scope  ##
  scope :my_snaps, lambda {|user| where("sender_id = ? && receiver_id = ?", user,user)}

  ## Callbacks ##
  after_create :add_history_for_sender, :add_history_for_receiver
  after_update :update_history_for_sender_and_receiver
  
  ## Methods ##

  def add_history_for_sender
    @history = self.histories.build
    @history.username         = self.receiver.username if self.receiver.username.present?
    @history.snap_update_at   = self.updated_at
    @history.status           = self.sender_status
    @history.icon_status      =  "delivered" 
    @history.user_id          = self.sender.id
    @history.smsid            = self.smsid
    @history.save
  end

  def add_history_for_receiver
     if self.receiver.is_everyone? || self.sender.friend_relationships.find_by_friend_id(self.receiver.id).is_accepted?
     if self.receiver.has_device_id_and_type?
        self.receiver.send_gcm_notification(self.sender.username)              
     end   
      @history = self.histories.build
      @history.username         = self.sender.username if self.sender.username.present?
      @history.snap_update_at   = self.updated_at
      @history.status           = self.receiver_status
      @history.icon_status      = self.receiver_status
      @history.user_id          = self.receiver.id
      @history.avatar_url       = "#{DOMAIN_CONFIG}#{self.avatar.url}"
      @history.allow_sec        = self.allow_sec    
      @history.avatar_code      = self.avatar_fname
      @history.save
    end
  end

  def update_history_for_sender_and_receiver
    self.histories.each do |h|
      if h.user_id == self.sender_id
        h.status = "Opened"
      else
        h.status      = "Opened"
        h.avatar_url  = ""
        h.allow_sec   = nil
        h.avatar_code = nil
        h.icon_status = "Opened"
      end
      h.snap_update_at = self.updated_at
      h.save
    end
  end

  def change_status_of_sender_and_receiver(snap)
    #snap.sender_status   = "delivered"
    snap.sender_status   = "Pending" # for paid functionality after payment it's delivered
    snap.receiver_status = "Press and hold to view"
  end

  def generate_unique_avatar_file_name
    o      =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
    fname  =  (0...20).map{ o[rand(o.length)] }.join
  end

  ## Convert base64 to image ##
  def decode_image_data(img_data,fname)
    cid           =   URI.unescape(img_data)
    filename      =   fname
    file          =   File.open("#{Rails.root.to_s}/public/tmp/#{filename}.jpg","wb")
    temp2         =   ActiveSupport::Base64.decode64(cid)
    file.write(temp2)
    file.close
    f             =   File.open("#{Rails.root.to_s}/public/tmp/#{filename}.jpg")
    self.avatar   =   f
    f.close
    File.delete("#{Rails.root.to_s}/public/tmp/#{filename}.jpg")
  end



end
