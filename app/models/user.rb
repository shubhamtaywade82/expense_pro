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

  validates :country, presence: true
  validates :currency, presence: true

  before_validation :set_default_currency

  private

  def set_default_currency
    return if country.blank?

    self.currency ||= ISO3166::Country[country].currency.iso_code
  end
end
