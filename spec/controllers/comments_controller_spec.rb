require File.dirname(__FILE__) + '/../spec_helper'

describe CommentsController do
  before do
    @user = Factory(:confirmed_user)
    @project = Factory(:project)
    @project.add_user @user
    @jordi = Factory.create(:confirmed_user, :login => 'jordi')
    @project.add_user @jordi
  end

  describe "#create" do
    it "should set the current user as the author" do
      conversation = Factory(:conversation, :user => @jordi, :project => @project)
      Comment.last.user.should == @jordi

      login_as @user
      xhr :post, :create,
           :project_id => @project.permalink,
           :conversation_id => conversation.id,
           :comment => { :body => "Ieee" }

      Comment.last.user.should == @user
    end
  end
  
  describe "#like" do
    it "should set the current user as the liker" do      
      conversation = Factory(:conversation, :user => @jordi, :project => @project)
      Comment.last.user.should == @jordi
      comment = Comment.last
      login_as @user
      xhr :put, :like,
           :project_id => @project.permalink,
           :conversation_id => conversation.id,
           :id => comment.id
      comment.reload
      comment.like_users.should include(@user)
    end
    
    it "should allow unlikes" do      
      conversation = Factory(:conversation, :user => @jordi, :project => @project)
      Comment.last.user.should == @jordi
      comment = Comment.last
      login_as @user
      xhr :put, :like,
           :project_id => @project.permalink,
           :conversation_id => conversation.id,
           :id => comment.id
      comment.reload
      comment.like_users.should include(@user)
      xhr :delete, :like,
           :project_id => @project.permalink,
           :conversation_id => conversation.id,
           :id => comment.id
      comment.reload
      comment.like_users.should_not include(@user)
    end
    
    it "should only like once" do      
      conversation = Factory(:conversation, :user => @jordi, :project => @project)
      Comment.last.user.should == @jordi
      comment = Comment.last
      login_as @user
      xhr :put, :like,
          :project_id => @project.permalink,
          :conversation_id => conversation.id,
          :id => comment.id
      xhr :put, :like,
          :project_id => @project.permalink,
          :conversation_id => conversation.id,
          :id => comment.id
          
      comment.reload
      comment.like_users.should include(@user)
      comment.like_users.length.should == 1
    end
  end
end
