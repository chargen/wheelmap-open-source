# encoding: UTF-8
namespace :import do
  desc 'Import data from Stiftung Gesundheit'
  task :from_stiftung_gesundheit => :environment do
    file_name = ENV['FILE']
    raise "Use bundle exec rake import:from_stiftung_gesundheit FILE=<file_name>" unless file_name
    provider = Provider.find_or_create_by_name('Stiftung Gesundheit')
    headers = [:OSM_Id, :OSM_Type, :OSM_Name, :OSM_Rollstuhlstatus, :OSM_Latitude, :OSM_Longitude, :OSM_Strasse, :OSM_Hausnummer, :OSM_Stadt, :OSM_Plz, :AA_Direktlink, :AA_Ampel]
    CSV.foreach(file_name, :force_quotes => true, :headers => headers) do |row|
      poi_id = row[:OSM_Id].to_i
      if poi = (Poi.find(poi_id) rescue nil)
        next if (wheelchair = wheelchair_status_from(row[:"AA_Ampel"])) == 'unknown'
        provided_poi = ProvidedPoi.find_or_create_by_poi_id_and_provider_id(poi_id, provider.id)
        provided_poi.wheelchair = wheelchair
        provided_poi.url        = row[:"AA_Direktlink"]
        provided_poi.save!
      end
    end
  end

  def wheelchair_status_from(aa_ampel)
    case aa_ampel
    when 'Grün' then 'yes'
    when 'Gelb' then 'limited'
    when 'Rot'  then 'no'
    else
      'unknown'
    end
  end

end