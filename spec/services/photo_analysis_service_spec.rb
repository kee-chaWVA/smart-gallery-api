require "rails_helper"

RSpec.describe PhotoAnalysisService do
  describe ".call" do
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:embedding) { Array.new(512) { |i| i / 512.0 } }
    let(:photo) do
      Photo.create!(filename: "dog.jpg", file_path: "/tmp/dog.jpg", status: "uploaded").tap do |photo|
        photo.image.attach(io: StringIO.new("fake image bytes"), filename: "dog.jpg", content_type: "image/jpeg")
      end
    end

    before do
      stub_const("ENV", ENV.to_h.merge("ML_SERVICE_URL" => "http://ml.test"))

      # Use the real connection settings, but answer requests from `stubs` instead of the network.
      connection = described_class.connection
      connection.adapter(:test, stubs)
      allow(described_class).to receive(:connection).and_return(connection)
    end

    def stub_analyze(status:, body:)
      stubs.post("/analyze") do |env|
        @request = env
        [ status, { "Content-Type" => "application/json" }, body.to_json ]
      end
    end

    it "saves the tags and embedding and marks the photo processed" do
      stub_analyze(status: 200, body: { tags: [ "dog", "beach" ], embedding: embedding })

      described_class.call(photo)

      photo.reload
      expect(photo.tags).to eq([ "dog", "beach" ])
      # pgvector stores single-precision floats, so values come back rounded to ~7 digits.
      expect(photo.embedding).to match(embedding.map { |x| be_within(1e-6).of(x) })
      expect(photo.status).to eq("processed")
    end

    it "uploads the image as a multipart file" do
      stub_analyze(status: 200, body: { tags: [], embedding: embedding })

      described_class.call(photo)

      expect(@request.request_headers["Content-Type"]).to start_with("multipart/form-data")
    end

    it "raises and leaves the photo unchanged when the ML service fails" do
      stub_analyze(status: 400, body: { detail: "File is not a valid image" })

      expect {
        described_class.call(photo)
      }.to raise_error(RuntimeError, /ML service returned 400/)

      photo.reload
      expect(photo.status).to eq("uploaded")
      expect(photo.tags).to eq([])
      expect(photo.embedding).to be_nil
    end
  end
end
