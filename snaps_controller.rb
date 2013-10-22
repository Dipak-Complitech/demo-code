class Api::V1::SnapsController < Api::BaseController

  def index
    @histories = @current_user.histories.latest
    render :file => "api/v1/histories/index"
  end

  def create
    receiver_ids_2 = params[:snap][:receiver_detail].split(",")
    receiver_ids = receiver_ids_2
    error = 0
    if receiver_ids.present?
      receiver_ids.each do |id|
        @snap = Snap.new(params[:snap])
        @snap.receiver_id = id
        @snap.change_status_of_sender_and_receiver(@snap)
        @snap.avatar_fname = generate_unique_avatar_file_name_for_image(@snap)
        if params[:avatar].present?  && params[:avatar_content_type].to_s == "png"
          @snap.decode_image_data(params[:avatar],@snap.avatar_fname)
        elsif params[:avatar].present?  && params[:avatar_content_type].to_s == "mp4" 
          @snap.avatar = params[:avatar]            
        end
        cnum = xxxxxxxx
        if cnum.present?
          res = RestClient.get "http://xxxxxxx/sendsms.php", {:params => {:username => 'xxxx', :password =>'xxxx',:to=> cnum,:from=>602,:text=>"Hi #{@snap.sender.username} has send a snap to you!" }}
          sms_status = res.split("SMSID").last.gsub(":", " ").delete(" ")
          @snap.sender.free_sms_responses.create(:smsid => sms_status, :mobile_number => cnum, :plan => "602", :snap_status => "pending")
          sleep(5.0)        
          sms_response = RestClient.get "http://xxxxxxx/querysms.php?username=xxxx&password=xxxx&smsid=#{sms_status}"
          deliveryreport = sms_response.split("SMSC_DELIVERY_REPORT:").last.gsub("<br/>", "").gsub("\n\n", "")
          @snap.smsid = sms_status
          if @snap.save
            error = 1 
            update_his_score(@snap.sender)
            update_his_score(@snap.receiver)
          end
        end
      end
      if error == 1
        @histories = @current_user.histories
        render :file => "api/v1/histories/index"
      else
        render_json({errors: @snap.full_errors, status: 404}.to_json)    
      end
    else
       @histories = @current_user.histories
       render :file => "api/v1/histories/index"
    end
  end

  def destroy
    @snap = Snap.find(params[:id])
    if @snap.present?
      if @snap.avatar_file_name.present?
        @snap.avatar = nil
        @snap.avatar_image = nil if @snap.avatar_image.present?
        @snap.save
        render_json({message: "Successfully destroy!", status: 200}.to_json)      
      else        
        render_json({message: "Snap already viewed!", status: 200}.to_json)      
      end        
    else
      render_json({errors: "No Snap present!", status: 404}.to_json)
    end      
  end

  private

  def generate_unique_avatar_file_name_for_image(snap)
    avatar_fname = snap.generate_unique_avatar_file_name
    prev_string = Snap.find_by_avatar_fname(avatar_fname)
    if prev_string.present?
      avatar_fname = snap.generate_unique_avatar_file_name
    else
      avatar_fname
    end
  end
  
  def update_his_score(user)
    total_score = user.score + 1
    user.update_attribute("score", total_score)
  end
end