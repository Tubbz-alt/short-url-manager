require 'csv'
require 'gds_api/publishing_api'

namespace :redirects do
  desc "Import redirects"
  task :import, [:file, :change_path_reservation?, :update_existing?] => :environment do |_, args|
    args.with_defaults(
      change_path_reservation?: false,
      update_existing?: false,
    )

    data = CSV.read(args[:file])

    data.shift # Remove the CSV header

    created = 0
    updated = 0
    skipped = 0
    errors = {}

    publishing_api_client = GdsApi::PublishingApi.new(
      Plek.find('publishing-api'),
      bearer_token: ENV['PUBLISHING_API_BEARER_TOKEN'] || 'example'
    )

    begin
      data.each do |row|
        fields = {
          from_path: row[0],
          to_path: row[1],
        }

        fields[:route_type] = row[2] if row[2].present?
        fields[:segments_mode] = row[3] if row[3].present?

        redirect = Redirect.where(from_path: fields[:from_path]).first

        if redirect.present? && !args[:update_existing?]
          skipped += 1
          print '-'
          next
        end

        begin
          if args[:change_path_reservation?]
            publishing_api_client.put_path(
              fields[:from_path],
              publishing_app: 'short-url-manager',
              override_existing: true,
            )
          end

          if redirect.present?
            redirect.update!(fields)
            updated += 1
            print '*'
          else
            Redirect.create!(fields)
            created += 1
            print '.'
          end
        rescue StandardError => e
          errors[row] = e

          print 'x'
        end
      end
    rescue Interrupt
      puts "Stopping due to interrupt"
    end

    puts

    errors.each do |row, error|
      puts "Row: #{row}"
      puts error
    end

    puts
    puts "Import finished:"
    puts "  - created: #{created}"
    puts "  - updated: #{updated}"
    puts "  - skipped: #{skipped}"
    puts "  -  errors: #{errors.size}"
  end
end
