RSpec.describe Veri::Authenticatable do
  describe "included" do
    it "raises an error if included more than once" do
      expect { Client.include(described_class) }.to raise_error(Veri::Error, "Veri::Authenticatable can only be included once")
    end
  end

  describe "sessions" do
    let(:user) { User.create! }
    let!(:sessions) do
      Array.new(3) do |i|
        Veri::Session.create!(
          authenticatable: user,
          expires_at: 1.hour.ago + i.hours,
          hashed_token: "foo#{i}",
          last_seen_at: Time.current
        )
      end
    end

    it "returns all sessions for the authenticatable" do
      expect(user.veri_sessions).to match_array(sessions)
    end
  end

  describe "#update_password" do
    subject { user.update_password(password) }

    let(:user) { User.create! }

    context "when the password is invalid" do
      let(:password) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError, "Expected a non-empty string, got `nil`")
      end
    end

    context "when the password is valid" do
      let(:password) { "new_password" }

      before { allow(Veri::Configuration.hasher).to receive(:create).with(password).and_return("hashed_password") }

      it "updates the hashed password and password updated at timestamp" do
        expect { subject }
          .to change(user, :hashed_password).from(nil).to("hashed_password")
          .and change(user, :password_updated_at).from(nil).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe "#verify_password" do
    subject { user.verify_password(password) }

    let(:user) { User.create!(hashed_password: "hashed_password") }

    context "when the password is invalid" do
      let(:password) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError, "Expected a non-empty string, got `nil`")
      end
    end

    context "when the password is incorrect" do
      let(:password) { "wrong_password" }

      before { allow(Veri::Configuration.hasher).to receive(:verify).with(password, user.hashed_password).and_return(false) }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when the password is correct" do
      let(:password) { "correct_password" }

      before { allow(Veri::Configuration.hasher).to receive(:verify).with(password, user.hashed_password).and_return(true) }

      it "returns true" do
        expect(subject).to be true
      end
    end
  end

  describe "#lock!" do
    subject { user.lock! }

    let(:user) { User.create! }

    it "locks the user and sets locked_at timestamp" do
      expect { subject }
        .to change(user, :locked).from(false).to(true)
        .and change(user, :locked_at).from(nil).to be_within(1.second).of(Time.current)
    end
  end

  describe "#unlock!" do
    subject { user.unlock! }

    let(:user) { User.create!(locked: true, locked_at: 1.hour.ago) }

    it "unlocks the user and clears locked_at timestamp" do
      expect { subject }
        .to change(user, :locked).from(true).to(false)
        .and change(user, :locked_at).from(be_present).to(nil)
    end
  end

  describe "#locked?" do
    subject { user.locked? }

    context "when user is not locked" do
      let(:user) { User.create!(locked: false) }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when user is locked" do
      let(:user) { User.create!(locked: true) }

      it "returns true" do
        expect(subject).to be true
      end
    end
  end
end
