class ::Endpoints::MultiplexedLibraryTubes < ::Endpoints::LibraryTubes
  instance do
    belongs_to(:custom_metadatum_collection, json: 'custom_metadatum_collection', to: 'custom_metadatum_collection')
    has_many(:requests, json: 'requests', to: 'requests')
    has_many(:studies, json: 'studies', to: 'studies')
    belongs_to(:purpose, json: 'purpose')
    has_many(:qc_files, json: 'qc_files', to: 'qc_files', include: []) do
      action(:create, as: 'create') do |request, _|
        ActiveRecord::Base.transaction do
          QcFile.create!(request.attributes.merge(asset: request.target))
        end
      end
      action(:create_from_file, as: 'create') do |request, _|
        ActiveRecord::Base.transaction do
          request.target.add_qc_file(request.file, request.filename)
        end
      end
    end
  end
end
