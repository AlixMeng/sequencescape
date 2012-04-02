class Admin::BaitLibraries::BaitLibraryTypesController < ApplicationController
  before_filter :admin_login_required
  before_filter :discover_bait_library_type, :only => [:edit, :update, :destroy]
  def new
    @bait_library_type = BaitLibraryType.new
  end

  def edit
  end

  def create
    @bait_library_type = BaitLibraryType.new(params[:bait_library_type])

    respond_to do |format|
      if @bait_library_type.save
        flash[:notice] = 'Bait Library Type was successfully created.'
        format.html { redirect_to(bait_libraries_path) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    respond_to do |format|
      if @bait_library_type.update_attributes(params[:bait_library_type])
        flash[:notice] = 'Bait Library Type was successfully updated.'
        format.html { redirect_to(bait_libraries_path) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    bait_libraries = BaitLibrary.find(
      :all,
      :conditions => ["visible = ? AND bait_library_type_id =?", true, @bait_library_type.id]
    )
    if bait_libraries.length > 0
      respond_to do |format|
        flash[:error] = "Can not delete '#{@bait_library_type.name}', bait library type is in use.<br/>
        Bait library type for: #{bait_libraries.map(&:name).join(', ')}."
        format.html { redirect_to(bait_libraries_path) }
      end
    else
      @bait_library_type.update_attributes(:visible => false)
      respond_to do |format|
        flash[:notice] = 'Bait Library Type was successfully deleted.'
        format.html { redirect_to(bait_libraries_path) }
      end
    end
  end
  private
  def discover_bait_library_type
    @bait_library_type = BaitLibraryType.find(params[:id])
  end
end