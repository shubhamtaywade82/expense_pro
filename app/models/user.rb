class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :incomes, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :credit_cards, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :username, uniqueness: { case_sensitive: false }, presence: true
  validates :mobile,
            presence: true,
            format: { with: /\A\d{10}\z/,
                      message: I18n.t("errors.messages.mobile_invalid") }
end
