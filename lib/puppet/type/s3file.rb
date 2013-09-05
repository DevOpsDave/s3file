=begin
require 'digest/md5'
require 'cgi'
require 'etc'
require 'uri'
require 'fileutils'
require 'enumerator'
require 'pathname'
require 'puppet/util/diff'
require 'puppet/util/checksums'
require 'puppet/util/backups'
require 'puppet/util/symbolic_file_mode'
=end


Puppet::Type.newtype(:s3file) do
=begin
  include Puppet::Util::MethodHelper
  include Puppet::Util::Checksums
  include Puppet::Util::Backups
  include Puppet::Util::SymbolicFileMode
=end

  @doc = "Manages files locally and in s3.  This resource extends the file type."

  ensurable do
    defaultvalues
    defaultto :present
  end

  def self.title_patterns
    [ [ /^(.*?)\/*\Z/m, [ [ :path ] ] ] ]
  end

  newparam(:path) do
    desc <<-'EOT'
      The path to the file to manage. Must be fully qualified.

      On Windows, the path should include the drive letter and should use `/` as
      the separator character (rather than `\\`).
    EOT
    isnamevar

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        fail Puppet::Error, "File paths must be fully qualified, not '#{value}'"
      end
    end

    munge do |value|
      ::File.expand_path(value)
    end
  end

  newparam(:s3_path) do
    desc 'Name of s3repo to get or put file.'
    newvalues(/.*:.*/)
  end

  newparam(:operation) do
    desc 'Do you want to get a file from s3 or put one.'
  end

  # Autorequire the file resource if it's being managed
  autorequire(:file) do
    req = []
    path = Pathname.new(self[:path])
    if !path.root?
      # Start at our parent, to avoid autorequiring ourself
      parents = path.parent.enum_for(:ascend)
      if found = parents.find { |p| catalog.resource(:file, p.to_s) }
        req << found.to_s
      end
    end
    # if the resource is a link, make sure the target is created first
    #req << self[:target] if self[:target]
    req
  end

  # Autorequire the owner and group of the file.
  {:user => :owner, :group => :group}.each do |type, property|
    autorequire(type) do
      if @parameters.include?(property)
        # The user/group property automatically converts to IDs
        next unless should = @parameters[property].shouldorig
        val = should[0]
        if val.is_a?(Integer) or val =~ /^\d+$/
          nil
        else
          val
        end
      end
    end
  end



=begin
  validate do
    unless self[:line] and self[:path]
      raise(Puppet::Error, "Both line and path are required attributes")
    end

    if (self[:match])
      unless Regexp.new(self[:match]).match(self[:line])
        raise(Puppet::Error, "When providing a 'match' parameter, the value must be a regex that matches against the value of your 'line' parameter")
      end
    end

  end
=end

end

require 'puppet/type/file/checksum'
require 'puppet/type/file/content' # can create the file
require 'puppet/type/file/source' # can create the file
require 'puppet/type/file/target' # creates a different type of file
require 'puppet/type/file/ensure' # can create the file
require 'puppet/type/file/owner'
require 'puppet/type/file/group'
require 'puppet/type/file/mode'
require 'puppet/type/file/type'
require 'puppet/type/file/selcontext' # SELinux file context
require 'puppet/type/file/ctime'
require 'puppet/type/file/mtime'
