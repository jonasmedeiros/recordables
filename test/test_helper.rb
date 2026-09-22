ENV["RAILS_ENV"] = "test"

require "openssl"
require_relative "dummy/config/environment"
require "minitest/autorun"
require "base64"
require "stringio"

Dir[File.expand_path("dummy/app/models/*.rb", __dir__)].sort.each { |model| require model }

ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

class RecordablesTest < Minitest::Test
  PIXEL = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  )

  TABLES = [
    ActiveStorage::Attachment, ActiveStorage::Blob, ActionText::RichText,
    Event, Recording, Post, Note, Page, Draft, Tag, Bucket, Project, User
  ].freeze

  def setup
    TABLES.each(&:delete_all)
    @actor = User.create!(name: "Jonas")
  end

  attr_reader :actor

  def attach_pixel(record, name: :cover, filename: "pixel.png")
    record.public_send(name).attach(
      io: StringIO.new(PIXEL), filename: filename, content_type: "image/png"
    )
  end
end
