require 'rubygems'
require 'aws-sdk'
require 'pry'
require 'digest/md5'

class FileObj

  attr_accessor :path, :s3_file, :s3_conn, :md5

  def initialize(path, fail_on_absent=false)
    @path = path

    @is_s3_file = false
    if @path =~ /:/
      @is_s3_file = true
      @s3_conn = connect_s3()
      (@s3_repo, @s3_key) = @path.split(':')
    end

    @md5 = get_md5

  end

  def read_data()

    data = ""
    if @is_s3_file == true
      s3_file = @s3_conn.buckets[@s3_repo].objects[@s3_key]
      data = s3_file.read()
    else
      data = File.open(@path, 'rb').read()
    end
    return data
  end

  def write_data(src_data)

    if @is_s3_file == true
      s3_file = @s3_conn.buckets[@s3_repo].objects[@s3_key]
      s3_file.write(src_data)
      @md5 = get_md5
    else
      fp = File.open(@path, 'wb')
      fp.write(src_data)
      fp.close
      @md5 = get_md5
    end

  end

  def get_md5()
    md5 = ""
    if @is_s3_file == true
      if @s3_conn.buckets[@s3_repo].objects[@s3_key].exists?
        md5 = @s3_conn.buckets[@s3_repo].objects[@s3_key].etag.gsub('"', '')
      else
        md5 = false
      end
    else
      if File.exists?(@path)
        md5 = Digest::MD5.hexdigest(File.read(@path))
      else
        md5 = false
      end
    end
    md5
  end

  def connect_s3()
    conn = AWS::S3.new
  end

end

Puppet::Type.type(:s3file).provide(:ruby) do

  def exists?
    # Depending on resource[:operation]:
    # if resource[:operation] = get ; then does s3_file.exists?()
    # if resource[:operation] = put ; then does local_file.exist?()
    #if resource[:operation] == 'get'
    #  File.exists?(@resource[:name])

    local_fileobj, remote_fileobj = get_data()

    # if the files differ return false.
    return (local_fileobj.md5 == remote_fileobj.md5)
  end

  def create
    local_fileobj, remote_fileobj = get_data()
    if not (local_fileobj.md5 == remote_fileobj.md5)
      sync_files(local_fileobj, remote_fileobj)
    end
  end

  def destroy
    local_fileobj, remote_fileobj = get_data()
    #local_fileobj.delete()
    #remote_fileobj.delete()
  end

  def get_data()
    case @resource[:operation]
      when 'get'
        local_file = FileObj.new(@resource[:path])
        remote_file = FileObj.new(@resource[:s3_path], fail_on_absent=true)
      when 'put'
        local_file = FileObj.new(@resource[:path], fail_on_absent=true)
        remote_file = FileObj.new(@resource[:s3_path])
      else
        raise("operation specification fail.")
    end

    return local_file, remote_file
  end

  def sync_files(local_fileobj, remote_fileobj)

    if @resource[:operation] == 'get'
      local_fileobj.write_data(remote_fileobj.read_data())
    elsif @resource[:operation] == 'put'
      remote_fileobj.write_data(local_fileobj.read_data())
    end

  end

end





