class TeamboxData
  def unserialize_teambox(dump, object_maps, opts={})
    ActiveRecord::Base.transaction do
      @object_map = {
        'User' => {},
        'Organization' => {}
      }.merge(object_maps)
      
      @processed_objects = {}
      @imported_users = @object_map['User']
      @organization_map = @object_map['Organization']
      
      @processed_objects[:user] = []
      
      @users = dump['users'].map do |udata|
        user_name = @imported_users[udata['username']] || udata['username']
        user = User.find_by_login(user_name)
        if user.nil? and opts[:create_users]
          user = User.new(udata)
          user.login = udata['username']
          user.password = user.password_confirmation = udata['password'] || rand().to_s
          user.save!
        end
        
        raise(Exception, "User #{user} could not be resolved") if user.nil?
        
        @imported_users[udata['id']] = user
        @processed_objects[:user] << user.id
        import_log(user, "#{udata['username']} -> #{user_name}")
      end.compact
      
      @processed_objects[:organization] = []
      @organizations = dump['organizations'].map do |organization_data|
        organization_name = @organization_map[organization_data['permalink']] || organization_data['permalink']
        organization = Organization.find_by_permalink(organization_name)
        
        if organization.nil? and opts[:create_organizations]
          organization = unpack_object(Organization.new, organization_data, []) if organization.nil?
          organization.permalink = organization_name if organization.nil?
          organization.save!
        end
        
        raise(Exception, "Organization #{organization} could not be resolved") if organization.nil?
        
        @organization_map[organization_data['id']] = organization
        @processed_objects[:user] << organization.id
        
        Array(organization_data['members']).each do |member_data|
          organization.add_member(resolve_user(member_data['user_id']), member_data['role'])
        end
      end
      
      @processed_objects[:project] = []
      @projects = dump['projects'].map do |project_data|
        @project = Project.find_by_permalink(project_data['permalink'])
        if @project
          project_data['permalink'] += "-#{rand}"
        end
        @project = unpack_object(Project.new, project_data, ['user_id'])
        @project.user = resolve_user(project_data['owner_user_id'])
        @project.organization = @organization_map[project_data['organization_id']] || @project.user.organizations.first
        @project.save!
        
        import_log(@project)
      
        Array(project_data['people']).each do |person_data|
          @project.add_user(resolve_user(person_data['user_id']), 
                            :role => person_data['role'],
                            :source_user => resolve_user(person_data['source_user_id']))
        end
        
        # Note on commentable objects: callbacks may be invoked which may change their state. 
        # For now we will play dumb and re-assign all attributes after we have unpacked comments.
      
        Array(project_data['conversations']).each do |conversation_data|
          conversation = unpack_object(@project.conversations.build, conversation_data)
          conversation.is_importing = true
          conversation.save!
          import_log(conversation)
        
          unpack_comments(conversation, conversation_data['comments'])
          unpack_object(conversation, conversation_data).save!
        end
      
        Array(project_data['task_lists']).each do |task_list_data|
          task_list = unpack_object(@project.task_lists.build, task_list_data)
          task_list.save!
          import_log(task_list)
        
          unpack_comments(task_list, task_list_data['comments'])
        
          Array(project_data['tasks']).each do |task_data|
            task = unpack_object(task_list.tasks.build, task_data)
            task.save!
            import_log(task)
            unpack_comments(task, task_data['comments'])
            unpack_object(task, task_data).save!
          end
          
          unpack_object(task_list, task_list_data).save!
        end
      
        Array(project_data['pages']).each do |page_data|
          page = unpack_object(@project.pages.build, page_data)
          page.save!
          import_log(page)
        
          obj_type_map = {'Note' => :notes, 'Divider' => :dividers}
        
          Array(page_data['slots']).each do |slot_data|
            next if obj_type_map[slot_data['rel_object_type']].nil? # not handled yet
            rel_object = unpack_object(page.send(obj_type_map[slot_data['rel_object_type']]).build, slot_data['rel_object'])
            rel_object.updated_by = page.user
            rel_object.save!
            rel_object.page_slot.position = slot_data['position']
            rel_object.page_slot.save!
            import_log(rel_object)
          end
        end
        
        @processed_objects[:project] << @project.id
      end
    end
  end
  
  def unpack_object(object, data, non_mass=[])
    object.tap do |obj|
      obj.attributes = data
      
      non_mass.each do |key|
        obj.send("#{key}=", data[key]) if data[key]
      end
      
      obj.project = @project if obj.respond_to? :project
      obj.user_id = resolve_user(data['user_id']).id if data['user_id']
      obj.watchers_ids = data['watchers'].map{|u| @imported_users[u].try(:id)}.compact if data['watchers']
      obj.created_at = data['created_at'] if data['created_at']
      obj.updated_at = data['updated_at'] if data['updated_at']
    end
  end
  
  def unpack_comments(obj, comments)
    return if comments.nil?
    comments.each do |comment_data|
      comment = unpack_object(@project.comments.build, comment_data)
      comment.target = obj
      comment.save!
      import_log(comment)
    end
  end
end