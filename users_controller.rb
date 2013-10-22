class Api::V1::UsersController < Api::BaseController

  skip_before_filter :authenticate_user_with_auth_token, :only => [:snaps_info]
  skip_before_filter :check_username_present_or_not, :only => [:snaps_info]

  def search
    @user = User.with_username(params[:username]).first
    if @user.present?
      render :file => "api/v1/users/base"
    else
      render_json({errors: "No user found with this username #{params[:username]}", status: 404}.to_json)
    end
  end

  def who_can
    who_can = params[:who_can]
    if who_can.present?
      if who_can.to_s == @current_user.snap_from
        render_json({message: "Your Snap privacy is already #{who_can}!", status: 200}.to_json)
      else
        @current_user.update_attributes(:snap_from => who_can)
        render_json({message: "Your Snap privacy update!", status: 200}.to_json)
      end
    else
      render_json({errors: "Who can can't blank!", status: 404}.to_json)
    end
  end

  def snaps_info
    if params[:username].present? 
      @user = User.find_by_username(params[:username])
      if @user.present?
        render :file => "api/v1/users/snaps_info"
      else
        render_json({errors: "Invalid User!", status: 404}.to_json) 
      end
    else
      render_json({errors: "Invalid User!", status: 404}.to_json) 
    end
  end

  def remove_history
    if @current_user.histories.present?
      @current_user.histories.delete_all
      render_json({message: "Successfully clear your histories", status: 200}.to_json) 
    else
      render_json({message: "Already Clear", status: 200}.to_json) 
    end
  end

  def update_device_token
    if params[:device_token].present?
      device_id   = params[:device_token]  
      @current_user.check_duplicate_device_ids(device_id, @current_user)
     
      render_json({message: "Successfully Added Device Token", status: 200}.to_json) 
    else
      render_json({errors: "Invalid Device id!", status: 404}.to_json) 
    end
  end

  def search_user_list
    if params[:search].present?
      @users_search = User.without_user(@current_user).search(params[:search])
      @users = @current_user.display_search_users_data(@users_search)
      if @users.count > 0
        render :file => "api/v1/users/search_user"
      else
        render_json({errors: "No user found with #{params[:search]}", status: 404}.to_json)
      end
    else
      render_json({errors: "Invalid Search", status: 404}.to_json)      
    end
  end

end