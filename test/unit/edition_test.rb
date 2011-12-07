require 'test_helper'

class EditionTest < ActiveSupport::TestCase

  def template_edition
    g = Guide.new(:name => "CHILDCARE", :slug=>"childcare")
    edition = g.editions.first
    edition.parts.build(:title => 'PART !', :body=>"This is some version text.", :slug => 'part-one')
    edition.parts.build(:title => 'PART !!', :body=>"This is some more version text.", :slug => 'part-two')
    edition
  end

  setup do
    panopticon_has_metadata("id" => '2356', "slug" => 'childcare',"name" => "Childcare")
  end

  test "editions, by default, return their title for use in the admin-interface lists of publications" do
    assert_equal template_edition.title, template_edition.admin_list_title
  end

  test "guides have at least one edition" do
    g = Guide.new(:slug=>"childcare")
    assert_equal 1, g.editions.length
  end

  test "editions can have notes stored for the history tab" do
    edition = template_edition
    user = User.new
    assert edition.new_action(user, 'note', comment: 'Something important')
  end

  test "status should not be affected by notes" do
    user = User.create(:name => "bob")
    edition = template_edition
    t0 = Time.now
    Timecop.freeze(t0) do
      edition.new_action(user, Action::APPROVE_REVIEW)
    end
    Timecop.freeze(t0 + 1) do
      edition.new_action(user, Action::NOTE, comment: 'Something important')
    end
    assert_equal Action::APPROVE_REVIEW, edition.latest_status_action.request_type
  end

  test "should have no assignee by default" do
    edition = template_edition
    assert_nil edition.assigned_to
  end

  test "should be assigned to the last assigned recipient" do
    alice = User.create(:name => "alice")
    bob   = User.create(:name => "bob")
    edition = template_edition
    alice.assign(edition, bob)
    assert_equal bob, edition.assigned_to
  end

  test "new edition should have an incremented version number" do
    g = Guide.new(:slug=>"childcare")
    edition = g.editions.first
    new_edition = edition.build_clone
    assert_equal edition.version_number + 1, new_edition.version_number
  end

  test "new editions should have the same text when created" do
    edition = template_edition
    new_edition = edition.build_clone
    original_text = edition.parts.map {|p| p.body }.join(" ")
    new_text = new_edition.parts.map  {|p| p.body }.join(" ")
    assert_equal original_text, new_text
  end

  test "changing text in a new edition should not change text in old edition" do
    edition = template_edition
    new_edition = edition.build_clone
    new_edition.parts.first.body = "Some other version text"
    original_text = edition.parts.map     {|p| p.body }.join(" ")
    new_text =      new_edition.parts.map {|p| p.body }.join(" ")
    assert_not_equal original_text, new_text
  end

  test "a new guide has no published edition" do
    guide = template_edition.guide
    guide.save
    assert_nil guide.published_edition
  end

  test "an edition of a guide can be published" do
    edition = template_edition
    guide = template_edition.guide
    guide.editions.first.update_attribute :state, 'ready'
    guide.editions.first.publish
    assert_not_nil guide.published_edition
  end

  test "when an edition of a guide is published, all other published editions are archived" do
    guide = Guide.new(:name => "CHILDCARE", :slug=>"childcare")

    first_edition = guide.editions.create(version_number: 1)
    first_edition.update_attribute(:state, 'published')

    second_edition = guide.editions.create(version_number: 2)
    second_edition.update_attribute(:state, 'published')

    new_edition = guide.editions.create(version_number: 3)
    new_edition.update_attribute(:state, 'ready')
    assert new_edition.publish

    assert_equal guide.editions.where(state: 'published').count, 1
    assert_equal guide.editions.where(state: 'archived').count, 2
  end

  test "a published edition can't be edited" do
    edition = template_edition
    guide = template_edition.container
    guide.save

    guide.editions.first.update_attribute :state, 'published'
    guide.reload

    edition = guide.editions.last
    edition.title = "My New Title"

    assert ! edition.save
    assert_equal ["Published editions can't be edited"], edition.errors[:base]
  end

  test "publish history is recorded" do
    without_metadata_denormalisation(Guide) do
      edition = template_edition                                     
      guide = template_edition.guide
      
      user = User.create :name => 'bob'
      guide.save                
                         
      edition = guide.editions.first
      edition.update_attribute(:state, 'ready')
      user.publish edition, comment: "First publication"      

      second_edition = guide.editions.build
      second_edition.save!
      second_edition.update_attribute(:state, 'ready')
      user.publish second_edition, comment: "Second publication"  

      third_edition = guide.editions.build
      third_edition.save!
      third_edition.update_attribute(:state, 'ready')                 
      user.publish third_edition, comment: "Third publication"

      guide.reload
                                       
      action_count = 0
      guide.editions.each do |e|                        
        actions = e.actions.where('request_type' => 'publish')
        action_count += actions.count   
      end
      
      assert_equal 3, action_count
      assert_equal 1, guide.editions.where(state: 'published').count
      assert_equal 2, guide.editions.where(state: 'archived').count
    end
  end
end
