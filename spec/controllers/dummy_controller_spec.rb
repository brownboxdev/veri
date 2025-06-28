RSpec.describe DummyController, type: :controller do
  let(:user) { User.create! }

  describe "when user is logged in and session is active and not expired" do
    let(:user) { User.create! }

    before { controller.log_in(user) }

    it "allows access" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "updates the session" do
      travel_to 1.hour.from_now do
        get :index
        session = controller.current_session
        expect(session.last_seen_at).to be_within(1.second).of(Time.current)
        expect(session.ip_address).to eq(request.remote_ip)
        expect(session.user_agent).to eq(request.user_agent)
      end
    end

    it "does not set the return path" do
      get :index
      expect(controller.return_path).to be_nil
    end
  end

  describe "when user is not logged in" do
    it "does not allow access when request format is HTML" do
      get :index
      expect(response).to redirect_to(DummyApplication.routes.url_helpers.root_path)
    end

    it "does not allow access when request format is not HTML" do
      get :index, format: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "sets the return path when request format is HTML" do
      get :index
      expect(controller.return_path).to eq(request.fullpath)
    end

    it "does not set the return path when request format is not HTML" do
      get :index, format: :json
      expect(controller.return_path).to be_nil
    end
  end

  context "when user is logged in but session is inactive" do
    before do
      Veri.configure { _1.inactive_session_lifetime = 1.hour }
      controller.log_in(user)
    end

    it "does not allow access when request format is HTML" do
      travel_to 2.hours.from_now do
        get :index
        expect(response).to redirect_to(DummyApplication.routes.url_helpers.root_path)
      end
    end

    it "does not allow access when request format is not HTML" do
      travel_to 2.hours.from_now do
        get :index, format: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "terminates the session" do
      travel_to 2.hours.from_now do
        expect { get :index }.to change(Veri::Session, :count).from(1).to(0)
      end
    end

    it "deletes the veri_token cookie" do
      travel_to 2.hours.from_now do
        expect { get :index }.to change { controller.send(:cookies).encrypted[:veri_token] }.from(be_present).to(be_nil)
      end
    end

    it "sets the return path if request format is HTML" do
      travel_to 2.hours.from_now do
        get :index
        expect(controller.return_path).to eq(request.fullpath)
      end
    end

    it "does not set the return path if request format is not HTML" do
      travel_to 2.hours.from_now do
        get :index, format: :json
        expect(controller.return_path).to be_nil
      end
    end
  end

  context "when user is logged in but session is expired" do
    before do
      Veri.configure { _1.total_session_lifetime = 1.hour }
      controller.log_in(user)
    end

    it "does not allow access when request format is HTML" do
      travel_to 2.hours.from_now do
        get :index
        expect(response).to redirect_to(DummyApplication.routes.url_helpers.root_path)
      end
    end

    it "does not allow access when request format is not HTML" do
      travel_to 2.hours.from_now do
        get :index, format: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "terminates the session" do
      travel_to 2.hours.from_now do
        expect { get :index }.to change(Veri::Session, :count).from(1).to(0)
      end
    end

    it "deletes the veri_token cookie" do
      travel_to 2.hours.from_now do
        expect { get :index }.to change { controller.send(:cookies).encrypted[:veri_token] }.from(be_present).to(be_nil)
      end
    end

    it "sets the return path if request format is HTML" do
      travel_to 2.hours.from_now do
        get :index
        expect(controller.return_path).to eq(request.fullpath)
      end
    end

    it "does not set the return path if request format is not HTML" do
      travel_to 2.hours.from_now do
        get :index, format: :json
        expect(controller.return_path).to be_nil
      end
    end
  end

  context "when user is logged in but account is locked" do
    let(:user) { User.create!(locked: true) }

    before do
      user.update!(locked: false)
      controller.log_in(user)
      user.update!(locked: true)
    end

    it "does not allow access when request format is HTML" do
      get :index
      expect(response).to redirect_to(DummyApplication.routes.url_helpers.root_path)
    end

    it "does not allow access when request format is not HTML" do
      get :index, format: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "terminates the session" do
      expect { get :index }.to change(Veri::Session, :count).from(1).to(0)
    end

    it "deletes the veri_token cookie" do
      expect { get :index }.to change { controller.send(:cookies).encrypted[:veri_token] }.from(be_present).to(be_nil)
    end

    it "does not set the return path if request format is HTML" do
      get :index
      expect(controller.return_path).to be_nil
    end

    it "does not set the return path if request format is not HTML" do
      get :index, format: :json
      expect(controller.return_path).to be_nil
    end
  end
end
