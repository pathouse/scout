# queue of to-be-delivered items
# designed to stay empty, inbox-zero style, with completed deliveries stored separately

class Delivery
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :subscription
  belongs_to :interest
  belongs_to :user
  
  field :subscription_id
  field :user_id
  field :interest_id
  
  # core fields needed to deliver the goods
  field :user_email
  field :subscription_type
  field :interest_in

  # store where this delivery should go out over email or sms
  # the delivery task should look at *this* field, so that we can
  # add the ability to override per-interest, per-subscription, whatever
  field :mechanism
  
  # item details
  field :item, :type => Hash, :default => {}
  
  index :subscription_type
  index :user_email
  index "item.date"
  
  validates_presence_of :subscription_id
  validates_presence_of :subscription_type
  validates_presence_of :interest_in
  validates_presence_of :user_id
  validates_presence_of :item


  def self.schedule!(user, subscription, item, mechanism, email_frequency)
    create! :user_id => user.id,
      :user_email => user.email,
      :user_phone => user.phone,
      
      :subscription_id => subscription.id,
      :subscription_type => subscription.subscription_type,
      
      :interest_in => subscription.interest_in,
      :interest_id => subscription.interest_id,

      :mechanism => mechanism,
      :email_frequency => email_frequency,
      
      # drop the item into the delivery wholesale
      :item => item.attributes.dup
  end
end