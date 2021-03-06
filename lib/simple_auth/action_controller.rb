module SimpleAuth
  module ActionController
    def self.included(base)
      base.class_eval do
        include InstanceMethods
        extend ClassMethods
      end
    end

    module InstanceMethods
      private
      def return_to(url = nil, &block)
        url = session.delete(:return_to) || url
        url = instance_eval(&block) if block_given?
        url
      end

      def current_session
        @current_session ||= SimpleAuth::Session.find
      end

      def current_user
        current_session && current_session.record
      end

      def authorized?
        true
      end

      def logged_in?
        current_user != nil
      end

      def activate_simple_auth
        SimpleAuth::Config.controller = self
      end

      def simple_auth_url_for(method, controller, path)
        path ||= SimpleAuth::Config.send(method)
        path = controller.instance_eval(&path) if path.kind_of?(Proc)
        path
      end
    end

    module ClassMethods
      # Redirect unlogged users to the specified <tt>:to</tt> path
      #
      #   require_logged_user :to => proc { login_path }
      #   require_logged_user :to => {:controller => "session", :action => "new"}
      #   require_logged_user :only => [:index], :to => login_path
      #   require_logged_user :except => [:public], :to => login_path
      #
      # You can set login url globally:
      #
      #   SimpleAuth::Config.login_url = {:controller => "session", :action => "new"}
      #   SimpleAuth::Config.login_url = proc { login_path }
      #
      def require_logged_user(options = {})
        before_filter options.except(:to) do |controller|
          controller.instance_eval do
            unless current_session && current_session.valid? && authorized?
              if request.respond_to?(:fullpath)
                return_to = request.fullpath
              else
                return_to = request.request_uri
              end

              session[:return_to] = return_to if request.get?

              SimpleAuth::Session.destroy!
              redirect_to simple_auth_url_for(:login_url, controller, options[:to]), :alert => t("simple_auth.sessions.need_to_be_logged")
            end
          end
        end
      end

      # Redirect logged users to the specified <tt>:to</tt> path
      #
      #   redirect_logged_user :to => proc { login_path }
      #   redirect_logged_user :to => {:controller => "dashboard"}
      #   redirect_logged_user :only => [:index], :to => login_path
      #   redirect_logged_user :except => [:public], :to => login_path
      #
      # You can set the logged url globally:
      #
      #   SimpleAuth::Config.logged_url = {:controller => "dashboard", :action => "index"}
      #   SimpleAuth::Config.logged_url = proc { dashboard_path }
      #
      def redirect_logged_user(options = {})
        before_filter options.except(:to) do |controller|
          controller.instance_eval do
            redirect_to simple_auth_url_for(:logged_url, controller, options[:to]) if logged_in?
          end
        end
      end
    end
  end
end
