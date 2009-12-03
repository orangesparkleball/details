module UploadsHelper
  def upload_primer(project)
    render :partial => 'uploads/primer', :locals => { :project => project }
  end

  def the_comment_upload_link(comment)
    link_to_function image_tag('attach_button.jpg'), show_upload_form(comment), :id => 'comment_upload_link'
  end

  def upload_iframe_form(comment)
    render :partial => 'uploads/iframe_upload', 
    :locals => { 
      :comment => comment }    
  end

  def edit_side_upload_form(project,upload)
    render :partial => 'uploads/side_edit', :locals => { :project => project, :upload => upload }
  end

  def show_upload(upload)
    # TODO: Find why some uploads get saved as with :file_type => nil
    if upload and upload.file_type
      render :partial => 'uploads/upload', :locals => { :project => upload.project, :upload => upload }
    end
   end

  def list_uploads(project,uploads)
    render :partial => 'uploads/upload', :collection => uploads, :as => :upload, :locals => { :project => project }    
  end

  def edit_upload_form(project,upload)
    render :partial => 'uploads/edit', :locals => {
      :project => project,
      :upload => upload }
  end
      
  def upload_actions_links(upload)
    render :partial => 'uploads/actions',
    :locals => { 
      :upload => upload }
  end

  def upload_link(project,upload)
    if upload.file_name.length > 25
      file_name = upload.file_name.sub(/^.+\./,truncate(upload.file_name,20,'~.'))
    else
      file_name = upload.file_name
    end  
      
    link_to file_name, upload.url, :class => 'upload_link'
  end
    
  def upload_link_with_thumbnail(upload)
    link_to image_tag(upload.asset(:thumb)),
      upload.url,
      :class => 'link_to_upload'
  end

  def upload_area(comment)
    render :partial => 'uploads/upload_area', :locals => {:comment => comment }
  end

  def show_upload_form(comment)
    update_page do |page|
      page['upload_area'].show
      page['comment_upload_link'].hide
    end  
  end

  def insert_upload_form(comment)
    page.insert_html :after, "upload_area",
      :partial => 'uploads/iframe_upload', 
      :locals => { 
        :comment => comment, 
        :project => comment.project }
  end
  
  def upload_form_url_for(comment)
    if comment.new_record?
      project_uploads_url(comment.project)
    else
      project_comment_uploads_url(comment.project,comment)
    end
  end
  
  def upload_url_for(comment)
    if comment.new_record?
      new_project_upload_url(comment.project)
    else
      new_project_comment_upload_url(comment.project,comment)
    end
  end
  
  def list_uploads_edit(uploads,target)
    render :partial => 'uploads/upload_edit', :collection => uploads, :as => :upload, :locals => { :target => target }
  end
  
  def list_uploads_inline(uploads)
    render :partial => 'uploads/file', :collection => uploads, :as => :upload
  end

  def list_uploads_inline_with_thumbnails(uploads)
    render :partial => 'uploads/thumbnail', :collection => uploads, :as => :upload
  end
  
  def observe_upload_form
    update_page_tag do |page|
      page['upload_file'].observe('change') do |page|
        page['new_upload'].submit
        page['new_upload'].hide
        page['upload_iframe_form_loading'].show
      end
    end
  end
  
  def cancel_upload_form_link
    link_to_function 'cancel', cancel_upload_form
  end
  

  def delete_upload_link(upload,target = nil)
    if target.nil?
      link_to_remote trash_image, 
        :url => project_upload_path(upload.project,upload), 
        :method => :delete, 
        :class => 'delete_link', 
        :confirm => "Are you sure you want to delete this file?"
    else
      link_to_function 'Remove', delete_upload(upload,target), :class => 'remove'
    end
  end

  def upload_form_params(comment)
    render :partial => 'uploads/iframe_upload', :locals => { :comment => comment, :upload => Upload.new }
  end
  
  def upload_save_tag(name,upload)
    content_tag(:input,nil,{ :name => name,:type => 'hidden',:value => upload.id.to_s })
  end
  
  def add_upload_link
    link_to_function content_tag(:span, t('.new_file')), show_new_upload_form, :class => 'add_button', :id => "add_upload_link"
  end
  
  def show_new_upload_form
    update_page do |page|
      page['edit_upload'].show
      page['add_upload_link'].hide
    end
  end
    
  def delete_upload(upload,target)
    if target.new_record?
      update_page do |page|
        page["upload_#{upload.id}"].up('.uploads_current') \
          .previous('.uploads_save').select("input[value=#{upload.id}]") \
          .invoke('remove')
        page << "var uploads_current = $('upload_#{upload.id}').up('.uploads_current');"
        page["upload_#{upload.id}"].remove
        page << "Comment.update_uploads_current(uploads_current);"
      end
    else
      update_page do |page|
        page << "$('upload_#{upload.id}').up('.uploads_current')" + \
          ".previous('.uploads_save').insert(" + \
          { :top => upload_save_tag('uploads_deleted[]',upload) }.to_json + ");"
        page["upload_#{upload.id}"].remove
      end
    end
  end
  
  def edit_upload_link(upload)
    link_to_function pencil_image, show_edit_upload_form(upload), :class => 'edit_upload_link'
  end
    
  def show_edit_upload_form(upload)
    update_page do |page|
      page["upload_#{upload.id}"].down('.show_details').hide
      page["upload_#{upload.id}"].down('.edit_details').show
    end
  end
  
  
  def cancel_edit_link(upload)
    link_to_function t('common.cancel'), update_page { |page| page.hide_upload_form(upload) }
  end
  
  def file_icon_image(upload,size='48px')
    extension = File.extname(upload.file_name)
    if extension.length > 0
      extension = extension[1,10]
    end
    
    if Upload::ICONS.include?(extension)
      image_tag("file_icons/#{size}/#{extension}.png", :class => "file_icon #{extension}")
    else
      image_tag("file_icons/#{size}/_blank.png")
    end
  end
end
