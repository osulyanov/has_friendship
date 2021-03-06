module HasFriendship
  module Friendable

    def friendable?
      false
    end

    def has_friendship
      class_eval do
        has_many :friendships, as: :friendable,
                 class_name: "HasFriendship::Friendship", dependent: :destroy

        has_many :friends,
                  -> { where friendships: { status: 2 } },
                  through: :friendships

        has_many :requested_friends,
                  -> { where friendships: { status: 1 } },
                  through: :friendships,
                  source: :friend

        has_many :pending_friends,
                  -> { where friendships: { status: 0 } },
                  through: :friendships,
                  source: :friend

        def self.friendable?
          true
        end
      end

      include HasFriendship::Friendable::InstanceMethods
      include HasFriendship::Extender
    end

    module InstanceMethods

      def friend_request(friend)
        unless self == friend || HasFriendship::Friendship.exist?(self, friend)
          transaction do
            HasFriendship::Friendship.create_relation(self, friend, status: 0)
            HasFriendship::Friendship.create_relation(friend, self, status: 1)
          end
        end
      end

      def accept_request(friend)
        on_relation_with(friend) do |one, other|
          friendship = HasFriendship::Friendship.find_unblocked_friendship(one, other)
          friendship.accept! if can_accept_request?(friendship)
        end
      end

      def decline_request(friend)
        on_relation_with(friend) do |one, other|
          HasFriendship::Friendship.find_unblocked_friendship(one, other).destroy
        end
      end

      alias_method :remove_friend, :decline_request

      def on_relation_with(friend)
        transaction do
          yield(self, friend)
          yield(friend, self)
        end
      end

      def friends_with?(friend)
        HasFriendship::Friendship.find_relation(self, friend, status: 2).any?
      end

      private

      def can_accept_request?(friendship)
        return if friendship.pending? && self == friendship.friendable
        return if friendship.requested? && self == friendship.friend

        true
      end
    end
  end
end
