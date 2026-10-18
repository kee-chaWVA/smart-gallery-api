# app/services/photo_upload_service.rb

class PhotoUploadService
  def self.call(photo)
    # A retry may find the image already attached if the previous run failed after
    # attaching; skip only the attach so the photo still gets marked and analyzed.
    unless photo.image.attached?
      File.open(photo.file_path) do |file|
        photo.image.attach(io: file, filename: photo.filename)
      end
    end

    photo.update!(status: "uploaded")
    PhotoAnalysisJob.perform_async(photo.id)
  end
end
