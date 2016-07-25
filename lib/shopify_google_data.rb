require "shopify_google_data/version"
require 'google/apis/sheets_v4'

require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
#
require 'credentials'
require 'shopify_google_data/product'

module ShopifyGoogleData


  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def self.authorize
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))
    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(
      client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(
        base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " +
        "resulting code after authorization"
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI)
    end
    credentials
  end

  def self.grab_inventory
    service = Google::Apis::SheetsV4::SheetsService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize
    spreadsheet_id = '1RFI-_EOYZ3DE0t2Qy7HC4WHsC3X2E2kY5xAwDQ702-4'
    range = 'C:D'
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    puts 'No data found.' if response.values.empty?
    response.values.each do |row|
      puts "#{row[0]}, #{row[1]}"
      ## Query based on JSON document
      # The -> operator returns the original JSON type (which might be an object), whereas ->> returns text
      # Event.where("payload->>'kind' = ?", "user_renamed")
      shopify_variants = ShopifyClone::where("data->>'sku' = ?", row[0] )
      
      if shopify_variants.any?
        matched_variant = shopify_variants.first
        
        mvsi = matched_variant.variant_inventory ? matched_variant.variant_inventory : VariantInventory.new
        mvsi.shopify_clone = matched_variant
        
        mvsi.initial_inventory = row[1]
        mvsi.save!
      end
    end
  end

end
