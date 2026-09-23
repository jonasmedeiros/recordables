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
  include Recordables::Testing

  PIXEL = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  )

  TABLES = [
    ActiveStorage::Attachment, ActiveStorage::Blob, ActionText::RichText,
    Event, Recording, Post, Note, Page, Draft, Topic, Board, Playlist, Track,
    Tag, Card, Bucket, Project, User
  ].freeze

  def setup
    # trashable's default_scope means Model.delete_all only clears rows
    # with an active Recording — a row trashed in one test would otherwise
    # survive into the next. with_trashed when it's defined (only Topic
    # here) clears the table for real, matching what every other model's
    # plain delete_all already does.
    TABLES.each { |table| table.respond_to?(:with_trashed) ? table.with_trashed.delete_all : table.delete_all }
    @actor = User.create!(name: "Jonas")
  end

  attr_reader :actor

  def attach_pixel(record, name: :cover, filename: "pixel.png")
    record.public_send(name).attach(
      io: StringIO.new(PIXEL), filename: filename, content_type: "image/png"
    )
  end
end
