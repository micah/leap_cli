#
# The Leapfile is the bootstrap configuration file for a LEAP provider.
#
# It is akin to a Gemfile, Rakefile, or Capfile (e.g. it is a ruby file that gets eval'ed)
#

module LeapCli
  def self.leapfile
    @leapfile ||= Leapfile.new
  end

  class Leapfile
    attr_accessor :platform_directory_path
    attr_accessor :provider_directory_path
    attr_accessor :custom_vagrant_vm_line
    attr_accessor :leap_version
    attr_accessor :log
    attr_accessor :vagrant_network
    attr_accessor :platform_branch
    attr_accessor :allow_production_deploy

    def initialize
      @vagrant_network = '10.5.5.0/24'
    end

    def load(search_directory=nil)
      directory = File.expand_path(find_in_directory_tree('Leapfile', search_directory))
      if directory == '/'
        return nil
      else
        #
        # set up paths
        #
        @provider_directory_path = directory
        read_settings(directory + '/Leapfile')
        read_settings(ENV['HOME'] + '/.leaprc')
        @platform_directory_path = File.expand_path(@platform_directory_path || '../leap_platform', @provider_directory_path)

        #
        # load the platform
        #
        require "#{@platform_directory_path}/platform.rb"
        if !Leap::Platform.compatible_with_cli?(LeapCli::VERSION)
          Util.bail! "This leap command (v#{LeapCli::VERSION}) " +
                     "is not compatible with the platform #{@platform_directory_path} (v#{Leap::Platform.version}). " +
                     "You need leap command #{Leap::Platform.compatible_cli.first} to #{Leap::Platform.compatible_cli.last}."
        end
        if !Leap::Platform.version_in_range?(LeapCli::COMPATIBLE_PLATFORM_VERSION)
          Util.bail! "This leap command (v#{LeapCli::VERSION}) " +
                     "is not compatible with the platform #{@platform_directory_path} (v#{Leap::Platform.version}). " +
                     "You need platform version #{LeapCli::COMPATIBLE_PLATFORM_VERSION.first} to #{LeapCli::COMPATIBLE_PLATFORM_VERSION.last}."
        end

        #
        # set defaults
        #
        if @allow_production_deploy.nil?
          # by default, only allow production deploys from 'master' or if not a git repo
          @allow_production_deploy = !LeapCli::Util.is_git_directory?(@provider_directory_path) ||
            LeapCli::Util.current_git_branch(@provider_directory_path) == 'master'
        end
        return true
      end
    end

    private

    def read_settings(file)
      if File.exists? file
        Util::log 2, :read, file
        instance_eval(File.read(file), file)
        validate(file)
      end
    end

    def find_in_directory_tree(filename, directory_tree=nil)
      search_dir = directory_tree || Dir.pwd
      while search_dir != "/"
        Dir.foreach(search_dir) do |f|
          return search_dir if f == filename
        end
        search_dir = File.dirname(search_dir)
      end
      return search_dir
    end

    PRIVATE_IP_RANGES = /(^127\.0\.0\.1)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)/

    def validate(file)
      Util::assert! vagrant_network =~ PRIVATE_IP_RANGES do
        Util::log 0, :error, "in #{file}: vagrant_network is not a local private network"
      end
    end

  end
end

