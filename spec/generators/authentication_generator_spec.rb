require "rails/generators"
require "generators/veri/authentication_generator"

RSpec.describe Veri::AuthenticationGenerator do
  subject { described_class.start(args) }

  let(:migration_file) { "db/migrate/20221201201056_add_veri_authentication.rb" }
  let(:migration_content) do
    <<~MIGRATION
      class AddVeriAuthentication < ActiveRecord::Migration[6.2]
        def change
          add_column :my_users, :hashed_password, :text
          add_column :my_users, :password_updated_at, :datetime
          add_column :my_users, :locked, :boolean, default: false, null: false
          add_column :my_users, :locked_at, :datetime

          create_table :veri_sessions#{", id: :uuid" if args.include?("--uuid")} do |t|
            t.string :hashed_token, null: false, index: { unique: true }
            t.datetime :expires_at, null: false
            t.belongs_to :authenticatable, null: false, foreign_key: { to_table: :my_users }, index: true#{", type: :uuid" if args.include?("--uuid")}
            t.belongs_to :original_authenticatable, foreign_key: { to_table: :my_users }, index: true#{", type: :uuid" if args.include?("--uuid")}
            t.datetime :shapeshifted_at
            t.datetime :last_seen_at, null: false
            t.string :ip_address
            t.string :user_agent

            t.timestamps
          end
        end
      end
    MIGRATION
  end

  before do
    allow(Time).to receive(:now).and_return(Time.new(2022, 12, 1, 21, 10, 56, "+01:00"))
    allow(ActiveRecord::Migration).to receive(:current_version).and_return(6.2)
    subject
  end

  after { FileUtils.rm_rf(Dir.glob("db")) }

  shared_examples "a migration generator" do
    it "generates a properly named migration file" do
      expect(File).to exist(migration_file)
    end

    it "generates a migration file with proper content" do
      expect(File.read(migration_file)).to eq(migration_content)
    end
  end

  context "when --uuid option is not provided" do
    let(:args) { [:my_users] }

    it_behaves_like "a migration generator"
  end

  context "when --uuid option is provided" do
    let(:args) { [:my_users, "--uuid"] }

    it_behaves_like "a migration generator"
  end
end
