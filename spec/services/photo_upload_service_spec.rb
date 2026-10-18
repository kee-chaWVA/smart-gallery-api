require "rails_helper"

RSpec.describe PhotoUploadService do
  describe ".call" do
    let(:file) do
      Tempfile.new([ "dog", ".jpg" ]).tap do |file|
        file.write("fake image bytes")
        file.flush
      end
    end
    let(:photo) { Photo.create!(filename: "dog.jpg", file_path: file.path, status: "pending") }

    before { Sidekiq::Job.clear_all }
    after { file.close! }

    it "attaches the image, marks the photo uploaded, and queues analysis" do
      described_class.call(photo)

      photo.reload
      expect(photo.image).to be_attached
      expect(photo.status).to eq("uploaded")
      expect(PhotoAnalysisJob.jobs.map { |job| job["args"] }).to eq([ [ photo.id ] ])
    end

    it "finishes a retry where the image was already attached" do
      photo.image.attach(io: StringIO.new("already uploaded"), filename: "dog.jpg")

      expect {
        described_class.call(photo)
      }.not_to change { photo.reload.image.blob.id }

      expect(photo.status).to eq("uploaded")
      expect(PhotoAnalysisJob.jobs.map { |job| job["args"] }).to eq([ [ photo.id ] ])
    end
  end
end
