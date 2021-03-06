namespace :export do
  require 'csv'
  require 'rgeo'

  desc 'Export CSV of nodes in a category'
  task :category_nodes => :environment do
    category_name = ENV['CATEGORY']
    raise "Run rake export:category_nodes CATEGORY=sport" unless category_name
    category = Category.find_by_identifier(category_name)
    raise "Category #{category_name} not found!" unless category
    csv_string = ""
    csv_string = CSV.generate(:force_quotes => true) do |csv|
      csv << ["osm_id", "lat", "lon", "Rollstuhlstatus", "Kommentar", "name", "Typ", "Strasse", "Hausnummer", "PLZ", "Stadt", "Telefon", "URL"]
      category.pois.find_each do |poi|
        csv << [poi.osm_id, poi.lat, poi.lon, poi.wheelchair, poi.wheelchair_description, poi.name, poi.node_type.try(:localized_name), poi.street, poi.housenumber, poi.postcode, poi.city, poi.phone, poi.website]
      end
    end
    puts csv_string
  end

  desc 'Export CSV of nodes in a category and region'
  task :filter_region_nodes => :environment do
    region_name = ENV['REGION']
    raise "Run rake export:filter_region_nodes REGION=berlin" unless region_name
    region = Region.find(region_name)

    bounding_box = RGeo::Cartesian::BoundingBox.create_from_geometry(region.grenze)

    csv_string = CSV.generate(:force_quotes => true) do |csv_out|
      FCSV(STDIN, :force_quotes => true, :headers => true) do |csv_in|
        csv_out << ["osm_id", "lat", "lon", "Rollstuhlstatus", "Kommentar", "name", "Typ", "Strasse", "Hausnummer", "PLZ", "Stadt", "Telefon", "URL"]
        csv_in.each do |row|
          point = factory.point(row[2].to_f, row[1].to_f)
          if bounding_box.contains?(point) && grenze.contains?(point)
            # csv << [poi.osm_id, poi.lat, poi.lon, poi.wheelchair, poi.wheelchair_description, poi.name, poi.node_type.try(:localized_name), poi.street, poi.housenumber, poi.postcode, poi.city, poi.phone, poi.website]
            csv_out << row
          end
        end
      end
    end
    STDOUT.puts csv_string
  end


  desc 'Export CSV of nodes in a region'
  task :region_nodes => :environment do
    region_name = ENV['REGION']
    raise "Run rake export:region_nodes REGION=Berlin" unless region_name
    region = Region.find_by_name(region_name)
    raise "Region #{region_name} not found!" unless region
    csv_string = ""
    csv_string = FasterCSV.generate(:force_quotes => true) do |csv|
      csv << ["osm_id", "lat", "lon", "Rollstuhlstatus", "Kommentar", "name", "Typ", "Strasse", "Hausnummer", "PLZ", "Stadt", "Telefon", "URL"]
      Poi.including_category.within_region(region).find_each do |poi|
        csv << [poi.osm_id, poi.lat, poi.lon, poi.wheelchair, poi.wheelchair_description, poi.name, poi.node_type.try(:localized_name), poi.street, poi.housenumber, poi.postcode, poi.city, poi.phone, poi.website]
      end
    end
    puts csv_string
  end

  desc 'Export Categories and NodeTypes'
  task :categories => :environment do
    csv_string = ""
    csv_string = CSV.generate(:force_quotes => true) do |csv|
      csv << ["wheelmap-Kategorien", "wheelmap-Typen", "OSM Key", "OSM Value"]
      Category.all.each do |category|
        category.node_types.each do |node_type|
          csv << [node_type.category.localized_name, node_type.localized_name, node_type.osm_key, node_type.osm_value]
        end
      end
    end
    puts csv_string
  end

  desc 'Export Categories and NodeTypes'
  task :node_type_fixture => :environment do
    NodeType.order('osm_value ASC').all.each do |n|
      puts "tag_#{n.identifier}:"
      puts "  osm_key: #{n.osm_key}"
      puts "  osm_value: #{n.osm_value}"
      puts
    end

  end


  desc 'Export Categories and NodeTypes'
  task :sorted_categories => :environment do
    csv_string = ""
    csv_string = CSV.generate(:force_quotes => true) do |csv|
      csv << ["wheelmap-Kategorien", "wheelmap-Typen", "OSM Key", "OSM Value"]
      Category.all.sort_by{|c| I18n.t("poi.category.#{c.identifier}")}.each do |category|
        category.node_types.sort_by{|n| I18n.t("poi.name.#{category.identifier}.#{n.identifier}")}.each do |node_type|
          csv << [node_type.category.localized_name, node_type.localized_name, node_type.osm_key, node_type.osm_value]
        end
      end
    end
    puts csv_string
  end

  desc 'Export nodes for yellow pages'
  task :for_yellow_pages => :environment do
    puts "Usage: rake export:for_yellow_pages region=Germany outfile=germany.csv"
    region_name = ENV['region'] || 'Germany'
    outfile = ENV['outfile'] || "#{region_name.downcase}.csv"

    CSV.open(outfile, "wb", :force_quotes => true) do |csv|
      csv << ["OSM ID", "OSM TYPE", "Name", "Kategorie", "Rollstuhlstatus", "lat", "lon", "Strasse", "Hausnummer", "Stadt", "Postleitzahl", "Telefon", "Webseite"]
      total_count = Region.find(region_name).pois_of_children.count
      progressbar = ProgressBar.create(:total => total_count, :format => '%a |%b>%i|')
      Region.find(region_name).pois_of_children.including_category.find_each(start: Poi.lowest_id) do |poi|
        csv << [poi.id, poi.node_type.localized_name, poi.name, poi.category.localized_name, poi.wheelchair, poi.lat, poi.lon, poi.street, poi.housenumber, poi.city, poi.postcode, poi.phone, poi.website]
        progressbar.increment
      end
    end
  end

  desc 'Export nodes for stiftung gesundheit'
  task :for_stiftung_gesundheit => :environment do
    puts "Usage: rake export:for_stiftung_gesundheit outfile=germany.csv"
    outfile = ENV['outfile'] || 'germany.csv'

    Geocoder.configure(
      # geocoding service (see below for supported options):
      :lookup => :nominatim,
      # geocoding service request timeout, in seconds (default 3):
      :timeout => 15,
      # set default units to kilometers:
      :units => :km,
      # use current locale
      :language => I18n.locale,
      # Make sure to tell the service, who is calling
      :http_headers => {
        "User-Agent" => "Wheelmap v1.0, (http://wheelmap.org)"
      }
    )

    CSV.open(outfile, "wb", :force_quotes => true) do |csv|
      csv << ["OSM_Id","OSM_Type","OSM_Name","OSM_Rollstuhlstatus","OSM_Latitude","OSM_Longitude","OSM_Strasse","OSM_Hausnummer","OSM_Stadt","OSM_Plz"]
      node_types = Category.find_by_identifier(:health).try(:node_types).map(&:id)
      total_count = Region.find('Germany').pois_of_children.where(node_type_id: node_types).count
      progressbar = ProgressBar.create(:total => total_count, :format => '%a |%b>%i|')
      Region.find('Germany').pois_of_children.where(node_type_id: node_types ).find_each(start: Poi.lowest_id) do |poi|
        if poi.street.blank? or poi.housenumber.blank? or poi.city.blank? or poi.postcode.blank?
          if result = Geocoder.search("#{poi.lat},#{poi.lon}").try(:first)
            poi.street = result.street if poi.street.blank?
            poi.housenumber = result.house_number if poi.housenumber.blank?
            poi.city = result.city if poi.city.blank?
            poi.postcode = result.postal_code if poi.postcode.blank?
          end
          sleep 1
        end
        csv << [poi.id, poi.node_type.localized_name, poi.name, poi.wheelchair, poi.lat, poi.lon, poi.street, poi.housenumber, poi.city, poi.postcode]
        progressbar.increment
      end
    end

  end

  desc 'Export nodes for streetspotr'
  task :for_streetspotr => :environment do
    region_names    = ENV['REGION'].split(',')      rescue nil
    category_names  = ENV['CATEGORIES'].split(',')  rescue nil
    limit           = ENV['LIMIT'].to_i             rescue nil
    raise "Usage: rake export:for_streetspotr REGIONs=Berlin,Leipzig CATEGORIES=shopping,leisure" unless region_names && category_names && limit

    regions = []
    region_names.each do |region_name|
      regions << Region.find_by_name(region_name)
    end

    categories = []
    category_names.each do |category_name|
      categories << Category.find_by_identifier(category_name)
    end

    CSV.open("streetspotr.csv", "wb", :force_quotes => true) do |csv|
      csv << ["Id","Name","Lat","Lon","Street","Housenumber","Postcode","City","Wheelchair","Type","Category"]
      regions.each do |region|
        categories.each do |category|
          Poi.unknown_accessibility.where(region_id: region).where(node_type_id: category.node_types).order('version DESC').limit(limit).each do |poi|
            csv <<
              [
                poi.id,
                poi.name,
                poi.lat,
                poi.lon,
                poi.street,
                poi.housenumber,
                poi.postcode,
                poi.city,
                poi.wheelchair,
                poi.node_type.identifier,
                poi.category.identifier
              ]
          end
        end
      end
    end
  end


  task :tags => :environment do
    puts "Tags = {"
    NodeType.order('osm_value ASC').all.each do |n|
      puts "  :#{n.osm_value} => :#{n.osm_key},"
    end
    puts "}"
  end

end