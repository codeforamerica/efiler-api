namespace :mef do
  desc "Show the MeF audit log fields the pinned gyr-efiler build writes, and how redaction treats each"
  task audit_log_labels: :environment do
    version = MefService::CURRENT_VERSION
    zip_path = Dir.glob(File.join(Dir.pwd, "gyr_efiler", "gyr-efiler-classes-#{version}.zip"))[0]
    abort("No classes zip for #{version}. Run `bundle exec ruby script/download_gyr_efiler.rb` first.") if zip_path.nil?

    # Only AuditImpl's own labels. The audit log also interleaves whatever the result
    # objects' toString emits, so this is not the log's complete vocabulary — but every
    # field the allowlist keeps comes from this class, and anything else is redacted anyway.
    audit_class = Zip::File.open(zip_path) { |zip| zip.read("gov/irs/mef/services/AuditImpl.class") }
    found = audit_class.scan(%r{\n([A-Z][A-Za-z0-9 /]{2,60}):}).flatten.uniq.sort

    puts "Audit log fields written by #{version}:"
    found.each do |label|
      treatment = MefService::AUDIT_LOG_ALLOWED_FIELDS.include?(label) ? "kept" : "redacted"
      puts format("  %-9s %s", treatment, label)
    end

    # The allowlist is append-only, so a kept field this build does not write is expected —
    # it belongs to another gyr-efiler version the same list has to serve.
    unwritten = MefService::AUDIT_LOG_ALLOWED_FIELDS - found
    unless unwritten.empty?
      puts
      puts "Kept by the allowlist but not written by this build: #{unwritten.join(", ")}"
    end
  end
end
