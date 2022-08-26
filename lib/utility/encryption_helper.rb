require 'openssl'

module Utility
  module EncryptionHelper
    ALGORITHM = 'prime256v1'
    CERT_FILE_PATH = '/tmp/temp_cert.pem'

    def self.local_pk_set?
      res = File.exists?(CERT_FILE_PATH)
      puts "EXISTS: #{res}"
      res
    end

    def self.read_local_pk
      OpenSSL::PKey::EC.new(File.read(CERT_FILE_PATH))
    end

    def self.generate_local_pk
      key = OpenSSL::PKey::EC.generate(ALGORITHM)
      puts "WRITING"

      File.open(CERT_FILE_PATH, "w") do |f|
        f.write(key.export)
      end
    end

    def self.parse_public_key(pk)
      puts "pk is: #{pk}"
      bn = OpenSSL::BN.new(pk)
      group = OpenSSL::PKey::EC::Group.new(ALGORITHM)

      OpenSSL::PKey::EC::Point.new(group, bn)
    end

    def self.build_shared_encryption_key(encryption_settings)
      puts "enc settings: #{encryption_settings}"
      connector_key = read_local_pk
      kibana_public_key = Utility::EncryptionHelper.parse_public_key(encryption_settings[:client_public_key])
      connector_key.dh_compute_key(kibana_public_key)

    def self.encrypt(encryption_settings, message)
      encryption_key = build_shared_encryption_key(encryption_settings)

      encryptor = ActiveSupport::MessageEncryptor.new(encryption_key)
      encrypted = encryptor.encrypt_and_sign(message)
      puts "encrypted: #{encrypted}\n"

      encrypted
    end
    end

    def self.decrypt(encryption_settings, message)
      encryption_key = build_shared_encryption_key(encryption_settings)

      decryptor = ActiveSupport::MessageEncryptor.new(encryption_key)
      decrypted = decryptor.decrypt_and_verify(message)

      puts "decrypted: #{decrypted}\n"

      decrypted
    end
  end
end
