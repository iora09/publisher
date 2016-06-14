class LocalContactImporter < LocalAuthorityDataImporter
  CONTACTS_LIST_URL = "http://local.direct.gov.uk/Data/local_authority_contact_details.csv"

  def self.fetch_data
    fetch_http_to_file(CONTACTS_LIST_URL)
  end

  private

  def process_row(row)
    return if row['SNAC Code'].blank?
    authority = LocalAuthority.where(:snac => row['SNAC Code']).first
    unless authority
      Rails.logger.warn "LocalContactImporter: failed to find LocalAuthority with SNAC #{row['SNAC Code']}"
      return
    end
    authority.name = decode_broken_entities( row['Name'] )
    authority.homepage_url = parse_url( row['Home page URL'] )
    authority.save!
  end

  def parse_url(url)
    if url.blank? || url.start_with?("http://") || url.start_with?("https://")
      url
    else
      "http://" + url
    end
  end


  # The CSV contains some broken HTML entities (e.g. &#40) note the missing ;
  # This will decode any printable ascii characters, and leave any others unchanged.
  def decode_broken_entities(string)
    return string if string.blank?

    # Catch any non-broken entities
    string = CGI.unescape_html(string)
    # Handle the broken entities (ones with a missing ;)
    string.gsub(/&\#([0-9]+)/) do
      n = $1.to_i
      if n > 31 and n < 127
        n.chr(string.encoding)
      else
        "&##{$1}"
      end
    end
  end
end
