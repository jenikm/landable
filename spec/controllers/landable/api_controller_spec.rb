require 'spec_helper'

describe Landable::ApiController, json: true do
  controller(Landable::ApiController) do
    skip_before_filter :require_author!, except: [:index]

    def index
      render nothing: true
    end

    def responder
      respond_with @resource
    end

    def update_responder
      respond_with @resource
    end

    def not_found
      raise ActiveRecord::RecordNotFound
    end

    def xml_only
      respond_to do |format|
        format.xml { render xml: '<lol/>' }
      end
    end

    def record_invalid
      Landable::Page.create!
    end

    def uuid_invalid
      Landable::Page.find('1')
    end

    def other_pg_error
      ActiveRecord::Base.connection.execute "LOL THIS IS NOT SQL AT ALL GUYS!"
    end
  end

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'responder' => 'anonymous#responder'
      patch 'responder' => 'anonymous#responder'
      put 'responder' => 'anonymous#responder'
      get 'not_found' => 'anonymous#not_found'
      get 'xml_only'  => 'anonymous#xml_only'
      get 'record_invalid' => 'anonymous#record_invalid'
      get 'uuid_invalid' => 'anonymous#uuid_invalid'
      get 'other_pg_error' => 'anonymous#other_pg_error'
    end
  end

  describe 'access token' do
    let(:author) { create :author }
    let(:token)  { create :access_token, author: author }
    let(:headers) do
      { 'HTTP_AUTHORIZATION' => encode_basic_auth(author.username, token.id) }
    end

    def make_request(params = nil)
      request.env.merge!(headers)
      get :index, params
    end

    it "sets current_author when valid" do
      make_request
      controller.send(:current_author).should == author
    end

    it "must be in the HTTP Authorization header" do
      headers.delete 'HTTP_AUTHORIZATION'
      make_request access_token: token.id
      response.status.should == 401
    end

    it "must belong to a valid Author username" do
      headers['HTTP_AUTHORIZATION'] = encode_basic_auth('wrong-username', token.id)
      make_request
      response.status.should == 401
    end

    it "must be an existing token ID" do
      headers['HTTP_AUTHORIZATION'] = encode_basic_auth(author.username, token.id.reverse)
      make_request
      response.status.should == 401
    end

    it "must not be expired" do
      token.update_attributes(expires_at: 1.minute.ago)
      make_request
      response.status.should == 401
    end
  end

  context 'rescues RecordNotFound' do
    it 'returns 404 Not Found' do
      get :not_found
      response.status.should == 404
    end
  end

  context 'rescues RecordInvalid' do
    it 'returns 422 Unprocessable Entity' do
      get :record_invalid
      response.status.should == 422
    end

    it 'renders ActiveModel::Errors as the JSON response' do
      get :record_invalid
      last_json['errors'].should have_key('path')
    end
  end

  context 'rescues UnknownFormat' do
    it 'returns 406 Not Acceptable' do
      request.env['HTTP_ACCEPT'] = 'text/plain'
      get :xml_only
      response.status.should == 406
    end
  end

  context 'rescues PG::Errors about invalid UUIDs' do
    it 'returns 404' do
      get :uuid_invalid
      response.status.should == 404
    end

    it 're-raises any other PG::Error' do
      expect {
        get :other_pg_error
      }.to raise_error(PG::Error)
    end
  end

  describe '#api_media' do
    let(:headers) { {} }

    def make_request
      request.env.merge!(headers)
      get :index
    end

    context 'a specific API version requested' do
      let(:headers) { {'HTTP_ACCEPT' => "application/vnd.landable.v3+json"} }

      it 'populates accordingly' do
        make_request

        controller.api_media.should == {
          format: :json,
          version: 3,
          param: nil,
        }
      end
    end

    context 'no specific API version requested' do
      let(:headers) { {'HTTP_ACCEPT' => "application/json"} }

      it 'should select defaults' do
        make_request

        controller.api_media.should == {
          format: :json,
          version: Landable::API_VERSION,
          param: nil,
        }
      end
    end
  end

  describe 'responder' do
    before(:each) do
      controller.instance_variable_set :@resource, resource
    end

    let(:resource) { build :author }

    it 'should set X-Landable-Media-Type' do
      get :responder
      response.status.should == 200
      response.headers['X-Landable-Media-Type'].should == "landable.v#{Landable::API_VERSION}; format=json"
    end

    context 'patch' do
      it 'should display the resource' do
        put :responder
        response.body.should_not be_empty
      end
    end

    context 'put' do
      it 'should display the resource' do
        put :responder
        response.body.should_not be_empty
      end
    end
  end
end
