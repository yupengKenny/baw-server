class AnalysisController < ApplicationController
  skip_authorization_check only: [:show]

  def show
    # normalise params and get access to rails request instance
    request_params = CleanParams.perform(params.dup)

    # should the response include content?
    is_head_request = request.head?

    # check that 'file_name' parameter is present, otherwise return an error
    unless request_params.include?(:file_name)
      fail CustomErrors::UnprocessableEntityError, 'Request must include the file name.'
    end

    # check that 'analysis_id' is present, otherwise return an error
    unless request_params.include?(:analysis_id)
      fail CustomErrors::UnprocessableEntityError, 'Request must include the analysis id.'
    end

    # check that 'format' matches 'file_name' extension
    request_ext = request_params[:format]
    file_ext = File.extname(request_params[:file_name]).trim('.','')
    if request_ext != file_ext
      fail CustomErrors::UnprocessableEntityError, "Request format '#{request_ext}' must match requested file extension '#{file_ext}'."
    end

    # check audio_recording authorisation
    audio_recording = authorise_custom(request_params, current_user)

    file_paths = BawWorkers::Config.analysis_cache_helper.existing_paths(
        {
            job_id: 'system', # TODO this is not provided at the moment, it will be once analyses are organised by job.
            uuid: audio_recording.uuid,
            sub_folders: [request_params[:analysis_id]],
            file_name: request_params[:file_name],
        })

    # return the first path that exists
    if file_paths.size > 0 && !is_head_request
      # return the file
      file_path = file_paths[0]
      ext = File.extname(file_path).trim('.','')
      mime_type = Mime::Type.lookup_by_extension(ext)
      send_file(file_path, url_based_filename: true, type: mime_type.to_s, content_length: File.size(file_path))

    elsif file_paths.size > 0 && is_head_request
      file_path = file_paths[0]
      ext = File.extname(file_path).trim('.','')
      mime_type = Mime::Type.lookup_by_extension(ext)
      head :ok, content_length: File.size(file_path), content_type: mime_type.to_s

    else
      # file was not found
      msg = "Could not find file '#{request_params[:file_name]}' generated by analysis '#{request_params[:analysis_id]}' from audio recording '#{audio_recording.id}'."
      fail CustomErrors::ItemNotFoundError, msg
    end

  end

  private

  def authorise_custom(request_params, user)

    # Can't do anything if not logged in, not in user or admin role, or not confirmed
    if user.blank? || (!Access::Check.is_standard_user?(user) && !Access::Check.is_admin?(user)) || !user.confirmed?
      fail CanCan::AccessDenied, 'Anonymous users, non-admin and non-users, or unconfirmed users cannot access analysis data.'
    end

    auth_custom_audio_recording(request_params.slice(:audio_recording_id))
  end
end