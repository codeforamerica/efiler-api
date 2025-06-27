# TODO: implement .with_lock or equivalent to prevent too many connections with mef (?)
class EfilerService
  # TODO: update to most recent commit
  CURRENT_VERSION = 'd8645b36cf2a9faa0593edb703411d8f4bea10df'
  RETRYABLE_LOG_CONTENTS = [
    /Transaction Result: The server sent HTTP status code 302: Moved Temporarily/,
    /connect timed out - Fault Code: soap:Server/,
    /Transaction Result: The server sent HTTP status code 401: Unauthorized/,
    /SSLException:Unsupported or unrecognized SSL message/,
    /Transaction Result: Fault String: Session limit reached/,
    /The server sent HTTP status code 503: Service Unavailable/,
    /Failed to parse XML document/,
    /Cookie validation for session/,
    /The server sent HTTP status code 500: Internal Server Error/,
    /HTTP transport error: java.net.ConnectException/,
    /HTTP transport error: javax.net.ssl.SSLException/,
  ]

  def self.run_efiler_command(*args)
    Dir.mktmpdir do |working_directory|
      FileUtils.mkdir_p(File.join(working_directory, "output", "log"))
      ensure_config_dir_prepared

      classes_zip_path = ensure_gyr_efiler_downloaded
      config_dir = File.join(Dir.pwd, "tmp", "gyr_efiler", "gyr_efiler_config")

      # On macOS, "java" will show a confusing pop-up if you run it without a JVM installed. Check for that and exit early.
      unless system('java', '-version', out: "/dev/null", err: '/dev/null')
        raise Error.new("Seems you are on a mac & lack Java. Refer to the README for instructions.")
      end

      # /Library/Java/JavaVirtualMachines
      java = ENV["VITA_MIN_JAVA_HOME"] ? File.join(ENV["VITA_MIN_JAVA_HOME"], "bin", "java") : "java"

      argv = [java, "-cp", classes_zip_path, "org.codeforamerica.gyr.efiler.App", config_dir, *args]
      pid = Process.spawn(*argv,
                          unsetenv_others: true,
                          chdir: working_directory,
                          in: "/dev/null"
      )
      Process.wait(pid)
      raise Error.new("Process failed to exit?") unless $?.exited?

      exit_code = $?.exitstatus
      if exit_code != 0
        log_contents = File.read(File.join(working_directory, 'audit_log.txt'))
        if log_contents.split("\n").include?("Transaction Result: java.net.SocketTimeoutException: Read timed out")
          raise RetryableError, log_contents
        elsif RETRYABLE_LOG_CONTENTS.any? { |contents| log_contents.match(contents) }
          raise RetryableError, log_contents
        else
          raise StandardError, log_contents
        end
      end

      get_single_file_from_zip(Dir.glob(File.join(working_directory, "output", "*.zip"))[0])
    end
  end

  private

  def self.ensure_config_dir_prepared
    config_dir = File.join(Dir.pwd, "tmp", "gyr_efiler", "gyr_efiler_config")
    FileUtils.mkdir_p(config_dir)
    return if File.exist?(File.join(config_dir, '.ready'))

    config_zip_path = Dir.glob(File.join(Dir.pwd, "gyr_efiler", "gyr-efiler-config-#{CURRENT_VERSION}.zip"))[0]
    raise StandardError.new("Please run `ruby scripts/download_gyr_efiler.rb` then try again") if config_zip_path.nil?

    system!("unzip -o #{config_zip_path} -d #{File.join(Dir.pwd,"tmp", "gyr_efiler")}")

    local_efiler_repo_config_path = File.expand_path('../gyr-efiler/gyr_efiler_config')
    if ENV['RACK_ENV'] && File.exist?(local_efiler_repo_config_path)
      begin
        FileUtils.cp(File.join(local_efiler_repo_config_path, 'gyr_secrets.properties'), config_dir)
        FileUtils.cp(File.join(local_efiler_repo_config_path, 'secret_key_and_cert.p12.key'), config_dir)
      rescue
        raise StandardError.new("Please clone the gyr-efiler repo to ../gyr-efiler and follow its README")
      end
    else
      app_sys_id, efile_cert_base64, etin = config_values

      properties_content = <<~PROPERTIES
          etin=#{etin}
          app_sys_id=#{app_sys_id}
        PROPERTIES
      File.write(File.join(config_dir, 'gyr_secrets.properties'), properties_content)
      File.write(File.join(config_dir, 'secret_key_and_cert.p12.key'), Base64.decode64(efile_cert_base64), mode: "wb")
    end

    FileUtils.touch(File.join(config_dir, '.ready'))
  end

  def self.ensure_gyr_efiler_downloaded
    classes_zip_path = Dir.glob(File.join(Dir.pwd, "gyr_efiler", "gyr-efiler-classes-#{CURRENT_VERSION}.zip"))[0]
    raise StandardError.new("You must run `ruby scripts/download_gyr_efiler.rb`") if classes_zip_path.nil?

    return classes_zip_path
  end

  def self.get_single_file_from_zip(zipfile_path)
    Zip::File.open(zipfile_path) do |zipfile|
      entries = zipfile.entries
      raise StandardError.new("Zip file contains more than 1 file") if entries.size != 1

      return zipfile.read(entries.first.name)
    end
  end

  def self.config_values
    # TODO add real credentials
    app_sys_id = "fake_app_sys_id"
    efile_cert_base64 = "fake_efile_cert_base64"
    etin = "fake_etin"
    if app_sys_id.nil? || efile_cert_base64.nil? || etin.nil?
      raise Error.new("Missing app_sys_id and/or efile_cert_base64 and/or etin configuration")
    end

    [app_sys_id, efile_cert_base64, etin]
  end

  def self.system!(*args)
    system(*args) || abort("\n== Command #{args} failed ==")
  end

  class RetryableError < StandardError; end
end