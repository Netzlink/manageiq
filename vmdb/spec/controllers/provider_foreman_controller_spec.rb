require "spec_helper"

describe ProviderForemanController do
  render_views
  before(:each) do
    set_user_privileges
    @zone = FactoryGirl.create(:zone, :name => 'zone1')
    @provider = ProviderForeman.create(:name => "test", :url => "10.8.96.102", :verify_ssl => nil, :zone => @zone)
    @config_mgr = ConfigurationManagerForeman.find_all_by_provider_id(@provider.id).first
    @config_profile = ConfigurationProfileForeman.create(:name                     => "testprofile",
                                                         :configuration_manager_id => @config_mgr.id)
    sb = {}
    temp = {}
    sb[:active_tree] = :foreman_providers_tree
    controller.instance_variable_set(:@sb, sb)
    controller.instance_variable_set(:@temp, temp)
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    response.should redirect_to(:action => 'explorer')
  end

  it "renders explorer" do
    session[:settings] = {:default_search => '',
                          :views          => {},
                          :perpage        => {:list => 10}}
    session[:userid] = User.current_user.userid
    session[:eligible_groups] = []
    EvmSpecHelper.create_guid_miq_server_zone
    get :explorer
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end

  it "renders show_list" do
    get :show_list
    expect(response.status).to eq(302)
    expect(response.body).to_not be_empty
  end

  it "renders a new page" do
    session[:settings] = {:views => {}, :perpage => {:list => 10}}
    post :new, :format => :js
    expect(response.status).to eq(200)
  end

  context "renders right cell text" do
    before do
      right_cell_text = nil
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      controller.stub(:process_show_list)
      controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
    end
    it "renders right cell text for root node" do
      key = ems_key_for_provider(@provider)
      controller.send(:get_node_info, key)
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq("All Foreman Providers")
    end

    it "renders right cell text for ConfigurationManagerForeman node" do
      key = ems_key_for_provider(@provider)
      controller.send(:x_node_set, key, :foreman_providers_tree)
      controller.send(:get_node_info, key)
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq("Provider \"test Configuration Manager\"")
    end
  end

  it "builds foreman tree" do
    controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
    first_child = find_treenode_for_provider(@provider)
    expect(first_child["title"]).to eq("test Configuration Manager")
  end

  context "renders tree_select" do
    before do
      right_cell_text = nil
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      controller.stub(:get_view_calculate_gtl_type)
      controller.stub(:get_view_pages)
      controller.stub(:build_listnav_search_list)
      controller.stub(:load_or_clear_adv_search)
      controller.stub(:replace_search_box)
      controller.stub(:update_partials)
      controller.stub(:render)

      settings = {}
      settings[:perpage] = {}
      settings[:perpage][:list] = 20
      controller.instance_variable_set(:@settings, settings)
      controller.stub(:items_per_page).and_return(20)
      controller.stub(:gtl_type).and_return("list")
      controller.stub(:current_page).and_return(1)
      controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
    end
    it "renders tree_select when the the node is a ConfigurationManagerForeman node" do
      ems_id = ems_key_for_provider(@provider)
      controller.instance_variable_set(:@_params, :id => ems_id)
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].data['name']).to eq("testprofile")
    end
  end

  def find_treenode_for_provider(provider)
    key =  ems_key_for_provider(provider)
    temp = controller.instance_variable_get(:@temp)
    tree =  JSON.parse(temp[:foreman_providers_tree])
    tree[0]['children'].find { |c| c['key'] == key }
  end

  def ems_key_for_provider(provider)
    ems = ExtManagementSystem.where(:provider_id => provider.id).first
    "e-" + ActiveRecord::Base.compress_id(ems.id)
  end
end
