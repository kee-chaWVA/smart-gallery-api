# app/services/photo_analysis_service.rb

class PhotoAnalysisService
  ANALYSIS_PATH = "/analyze"

  def self.call(photo)
    response = photo.image.open do |file|
      connection.post(ANALYSIS_PATH, {
        file: Faraday::Multipart::FilePart.new(file, photo.image.content_type, photo.filename)
      })
    end

    raise "ML service returned #{response.status}: #{response.body}" unless response.success?

    photo.update!(
      tags: response.body["tags"],
      embedding: response.body["embedding"],
      status: "processed"
    )
  end

  def self.connection
    Faraday.new(url: ENV.fetch("ML_SERVICE_URL")) do |f|
      f.request :multipart
      f.response :json
      f.options.open_timeout = 5
      f.options.timeout = 60
    end
  end
end
