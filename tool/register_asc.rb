#!/usr/bin/env ruby
# Registers the 7 Sancta Via apps with App Store Connect using the ASC API key
# (no Apple-ID login, no produce/spaceauth): creates bundle IDs on the
# developer portal if missing, App Store Connect app records for TestFlight,
# and IOS_APP_STORE provisioning profiles. Run via `ruby tool/register_asc.rb`.
#
# Values come from fastlane/.env (ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH).

require 'spaceship'
require 'dotenv'
Dotenv.load(File.expand_path('../fastlane/.env', __dir__))

TEAM_ID = 'U2267GC4DS'
KEY_PATH = ENV.fetch('ASC_KEY_PATH')
KEY_ID = ENV.fetch('ASC_KEY_ID')
ISSUER_ID = ENV.fetch('ASC_ISSUER_ID')

# Apple bundle IDs: alphanumeric + hyphens + periods only (no underscores —
# the ASC New App form rejects them). Hyphenated iOS ids differ from the
# Android applicationIds, which keep underscores (Google allows them; each
# store tracks its own identity permanently).
APPS = {
  'net.superversive.sancta-via.bible-reading-app' => 'Sancta Via Bible',
  'net.superversive.sancta-via.confession-companion' => 'Sancta Via Examen',
  'net.superversive.sancta-via.devotionals' => 'Sancta Via Devotionals',
  'net.superversive.sancta-via.liturgical-calendar-app' => 'Sancta Via Calendar',
  'net.superversive.sancta-via.novena-companion' => 'Sancta Via Novena',
  'net.superversive.sancta-via.prayer-companion' => 'Sancta Via Prayer',
  'net.superversive.sancta-via.saint-companion' => 'Sancta Via Saints',
}

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: KEY_ID,
  issuer_id: ISSUER_ID,
  filepath: KEY_PATH
)

client = Spaceship::ConnectAPI

# The distribution certificate must exist on the portal (minted via Xcode's
# GUI "Manage Certificates") - fetch its id for profile creation.
# Retire profiles bound to the invalid underscore bundle ids.
valid_ids = APPS.keys
legacy = client.get_profiles(includes: 'bundleId').to_a.select do |p|
  bundle = p.bundle_id
  bundle.is_a?(Spaceship::ConnectAPI::BundleId) &&
    p.profile_type == 'IOS_APP_STORE' &&
    !valid_ids.include?(bundle.identifier)
end
legacy.each do |p|
  begin
    client.delete_profiles(profile_id: p.id)
    puts "  deleted legacy profile #{p.name}"
  rescue StandardError => e
    puts "  (could not delete old profile #{p.name}: #{e.message})"
  end
end

certs = client.get_certificates(filter: { certificateType: 'DISTRIBUTION' })
raise 'no DISTRIBUTION certificate on the portal — mint it in Xcode' if certs.to_a.empty?
cert_ids = certs.to_a.map(&:id)
warn "portal distribution certs: #{cert_ids.join(', ')}"

APPS.each do |bundle_id, name|
  short_name = name

  # 1. Developer portal App ID.
  existing = Spaceship::ConnectAPI::BundleId.find(bundle_id)
  bundle = existing || Spaceship::ConnectAPI::BundleId.create(
    client: client, name: short_name, platform: 'IOS', identifier: bundle_id
  )
  puts "#{existing ? 'found ' : 'created'} bundle id #{bundle_id} (#{bundle.id})"

  # 2. App Store Connect app record (needed for TestFlight + listing).
  # NOTE: ASC API keys are not allowed to POST /apps on this account type -
  # records must be created by a human in App Store Connect (ASC → My Apps →
  # +). Treat as non-blocking; keep going (profiles + exports don't need it).
  found_app = Spaceship::ConnectAPI::App.find(bundle_id)
  if found_app
    puts '  ASC app record already exists'
  else
    begin
      Spaceship::ConnectAPI::App.create(
        name: short_name, version_string: '1.0', sku: bundle_id,
        primary_locale: 'en-US', bundle_id: bundle_id, platforms: ['IOS']
      )
      puts "  created ASC app record for #{name}"
    rescue Spaceship::AccessForbiddenError => e
      puts "  SKIPPED ASC app record (API keys can't create apps on this account) — create '#{name}' in ASC → My Apps → + with bundle #{bundle_id}"
    end
  end

  # 3. IOS_APP_STORE profile - the portal profiles endpoint does not support
  # a bundleId filter, so fetch all (including the bundleId relationship) and
  # match client-side.
  all_profiles = client.get_profiles(includes: 'bundleId').to_a
  mine = all_profiles.select do |p|
    p.profile_type == 'IOS_APP_STORE' &&
      (p.bundle_id.is_a?(String) ? p.bundle_id == bundle_id : p.bundle_id&.identifier == bundle_id)
  end
  if mine.any?
    puts "  App Store profile already exists: #{mine.first.name}"
    next
  end
  client.post_profiles(
    bundle_id_id: bundle.id,
    certificates: cert_ids,
    devices: [],
    attributes: { name: "#{short_name} App Store", profileType: 'IOS_APP_STORE' }
  )
  # Confirm server-side (the POST returns a raw Response, not a model).
  confirmed = client.get_profiles.to_a
                  .select { |p| p.bundle_id == bundle_id && p.profile_type == 'IOS_APP_STORE' }
  puts "  created App Store profile: #{confirmed.first.name}" if confirmed.any?
rescue StandardError => e
  puts "ERROR for #{bundle_id}: #{e.message} (#{e.class})"
end

puts 'done'
