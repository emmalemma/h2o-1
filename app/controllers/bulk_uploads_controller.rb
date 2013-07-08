class BulkUploadsController < ApplicationController
  before_filter :require_user
  before_filter :require_dropbox_session
  before_filter :initialize_dropbox_client, :only => [:new, :show]
  before_filter :add_assets, :only => [:show, :new]

  def show
    @bulk_upload = BulkUpload.find(params[:id])
  end

  def new
    @files_to_import = @dh2o.import_file_paths
  end

  def create
    bulk_upload = BulkUpload.create!
    BulkUploadsWorker.async_send_import(:dropbox_session => current_dropbox_session,
                                        :user_id => current_user.id,
                                        :bulk_upload_id => bulk_upload.id)
    flash[:notice] = "Download started. You will receive an email when it's finished.  You can also refresh this page to check progress."
    redirect_to bulk_upload_path(bulk_upload)
  end

  def require_dropbox_session
    unless current_dropbox_session
      redirect_to_dropbox_sessions
      false
    end
  end

  def initialize_dropbox_client
    begin
      @dh2o = DropboxH2o.new(current_dropbox_session)
    rescue DropboxAuthError
      redirect_to_dropbox_sessions
    end
  end

  def redirect_to_dropbox_sessions
    redirect_to(:controller => 'dropbox_sessions', :action => 'create')
  end

  def current_dropbox_session
    session[:dropbox_session]
  end

  def add_assets
    add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor', 'cases']
    add_stylesheets ['new_case']
  end
end