namespace :geolite2 do
  desc "Download the latest GeoLite2-City.mmdb database from MaxMind"
  task download: :environment do
    account_id = ENV["MAXMIND_ACCOUNT_ID"]
    license_key = ENV["MAXMIND_LICENSE_KEY"]

    if account_id.blank? || license_key.blank?
      puts <<~MSG
        MAXMIND_ACCOUNT_ID and/or MAXMIND_LICENSE_KEY are not set.

        To download the GeoLite2 database automatically, sign up for a free
        MaxMind account and generate a license key:

          https://www.maxmind.com/en/geolite2/signup

        Then add the credentials to your .env file:

          MAXMIND_ACCOUNT_ID=your_account_id
          MAXMIND_LICENSE_KEY=your_license_key

        Alternatively, download GeoLite2-City.mmdb manually from:

          https://www.maxmind.com/en/accounts/current/geoip/downloads

        and place it in the project root directory.
      MSG
      exit 1
    end

    require "net/http"
    require "uri"
    require "tmpdir"
    require "fileutils"
    require "rubygems/package"
    require "zlib"

    url = "https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz"
    dest = Rails.root.join("GeoLite2-City.mmdb")

    puts "Checking for GeoLite2-City updates..."

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    head_request = Net::HTTP::Head.new(uri)
    head_request.basic_auth(account_id, license_key)
    head_response = http.request(head_request)

    # Follow redirects for HEAD (MaxMind uses R2 presigned URLs)
    if head_response.is_a?(Net::HTTPRedirection)
      redirect_uri = URI(head_response["location"])
      redirect_http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
      redirect_http.use_ssl = true
      head_response = redirect_http.request(Net::HTTP::Head.new(redirect_uri))
    end

    remote_modified = head_response["last-modified"]
    puts "Remote Last-Modified: #{remote_modified}"

    if dest.exist?
      local_modified = File.mtime(dest).httpdate
      puts "Local  Last-Modified: #{local_modified}"

      if remote_modified && Time.httpdate(remote_modified) <= File.mtime(dest)
        puts "GeoLite2-City.mmdb is already up to date."
        next
      end
    end

    puts "Downloading GeoLite2-City database..."

    Dir.mktmpdir do |tmpdir|
      tarball = File.join(tmpdir, "geolite2-city.tar.gz")

      # Follow redirects for the actual download
      download_uri = uri
      loop do
        dl_http = Net::HTTP.new(download_uri.host, download_uri.port)
        dl_http.use_ssl = true

        request = Net::HTTP::Get.new(download_uri)
        request.basic_auth(account_id, license_key) if download_uri.host.include?("maxmind.com")

        response = dl_http.request(request)

        if response.is_a?(Net::HTTPRedirection)
          download_uri = URI(response["location"])
          next
        end

        unless response.is_a?(Net::HTTPSuccess)
          puts "Download failed: HTTP #{response.code} #{response.message}"
          exit 1
        end

        File.binwrite(tarball, response.body)
        break
      end

      # Extract the .mmdb file from the tarball
      Zlib::GzipReader.open(tarball) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          tar.each do |entry|
            if entry.full_name.end_with?("GeoLite2-City.mmdb")
              File.binwrite(dest.to_s, entry.read)
              puts "Saved GeoLite2-City.mmdb (#{(dest.size / 1024.0 / 1024.0).round(1)} MB)"
              break
            end
          end
        end
      end
    end

    unless dest.exist?
      puts "Error: GeoLite2-City.mmdb was not found in the downloaded archive."
      exit 1
    end

    puts "Done."
  end
end
