class Category < ApplicationRecord
  has_many :transactions, dependent: :nullify, class_name: "Transaction"
  has_many :import_mappings, as: :mappable, dependent: :destroy, class_name: "Import::Mapping"

  belongs_to :family

  has_many :budget_categories, dependent: :destroy
  has_many :subcategories, class_name: "Category", foreign_key: :parent_id, dependent: :nullify
  belongs_to :parent, class_name: "Category", optional: true

  validates :name, :color, :lucide_icon, :family, presence: true
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
  validates :name, uniqueness: { scope: :family_id }

  validate :category_level_limit

  before_save :inherit_color_from_parent

  scope :alphabetically, -> { order(:name) }
  scope :alphabetically_by_hierarchy, -> {
    left_joins(:parent)
      .order(Arel.sql("COALESCE(parents_categories.name, categories.name)"))
      .order(Arel.sql("parents_categories.name IS NOT NULL"))
      .order(:name)
  }
  scope :roots, -> { where(parent_id: nil) }
  # Legacy scopes - classification removed; these now return all categories
  scope :incomes, -> { all }
  scope :expenses, -> { all }

  COLORS = %w[#e99537 #4da568 #6471eb #db5a54 #df4e92 #c44fe9 #eb5429 #61c9ea #805dee #6ad28a]

  UNCATEGORIZED_COLOR = "#737373"
  OTHER_INVESTMENTS_COLOR = "#e99537"
  TRANSFER_COLOR = "#444CE7"
  PAYMENT_COLOR = "#db5a54"
  TRADE_COLOR = "#e99537"

  ICON_KEYWORDS = {
    /income|salary|paycheck|wage|earning|salaire|revenu|remboursement/            => "circle-dollar-sign",
    /groceries|grocery|supermarket|courses|épicerie|supermarché/                  => "shopping-bag",
    /food|dining|restaurant|meal|lunch|dinner|breakfast|nourriture|repas|déjeuner|dîner/ => "utensils",
    /coffee|cafe|café/                                                            => "coffee",
    /shopping|retail/                                                             => "shopping-cart",
    /transport|transit|commute|subway|metro/                                      => "bus",
    /parking|stationnement/                                                       => "circle-parking",
    /loan|debt|credit card|crédit|prêt/                                          => "credit-card",
    /car|auto|vehicle|voiture|véhicule/                                          => "car",
    /gas|fuel|petrol|essence|carburant/                                           => "fuel",
    /flight|airline|avion/                                                        => "plane",
    /travel|trip|vacation|holiday|voyage|vacances/                                => "plane",
    /hotel|lodging|accommodation|hôtel|hébergement/                              => "hotel",
    /movie|cinema|film|theater|theatre|cinéma|théâtre/                           => "film",
    /music|concert|musique/                                                       => "music",
    /game|gaming|jeux?\b/                                                         => "gamepad-2",
    /entertainment|leisure|divertissement|loisirs?/                               => "drama",
    /sport|fitness|gym|workout|exercise|entraînement/                            => "dumbbell",
    /pharmacy|drug|medicine|pill|medication|dental|dentist|pharmacie|médicament/ => "pill",
    /health|medical|clinic|doctor|physician|santé|médecin/                       => "stethoscope",
    /personal care|beauty|salon|spa|hair|soins|beauté|coiffure/                  => "scissors",
    /mortgage|rent|hypothèque|loyer/                                              => "home",
    /home|house|apartment|housing/                                                => "home",
    /improvement|renovation|remodel|travaux/                                      => "hammer",
    /repair|maintenance|réparation|entretien/                                     => "wrench",
    /electric|power|energy|électricité|énergie|climatisation/                    => "zap",
    /water|sewage/                                                                => "waves",
    /internet|cable|broadband|subscription|streaming|abonnements?/               => "wifi",
    /utilities|utility/                                                           => "lightbulb",
    /phone|telephone/                                                             => "phone",
    /mobile|cell|portable/                                                        => "smartphone",
    /insurance|assurance/                                                         => "shield",
    /gift|present|cadeau/                                                         => "gift",
    /donat|charity|nonprofit|charité/                                             => "hand-helping",
    /tax|irs|revenue|impôt|taxe/                                                 => "landmark",
    /service|professional|prestation/                                             => "briefcase",
    /fee|charge|frais/                                                            => "receipt",
    /bank|banking|banque/                                                         => "landmark",
    /saving|épargne|économies/                                                   => "piggy-bank",
    /invest|stock|fund|portfolio/                                                 => "trending-up",
    /pet|dog|cat|animal|vet|vétérinaire|croquettes?|chien/                      => "paw-print",
    /education|school|university|college|tuition|école|université|lycée/         => "graduation-cap",
    /book|reading|library|livre|lecture|bibliothèque/                            => "book",
    /child|kid|baby|infant|daycare|enfants?|bébé|crèche/                        => "baby",
    /cloth|apparel|fashion|wear|vêtement|habillement|mode/                       => "shirt",
    /ticket|billet/                                                               => "ticket"
  }.freeze

  # Category name keys for i18n
  UNCATEGORIZED_NAME_KEY = "models.category.uncategorized"
  OTHER_INVESTMENTS_NAME_KEY = "models.category.other_investments"
  INVESTMENT_CONTRIBUTIONS_NAME_KEY = "models.category.investment_contributions"

  class Group
    attr_reader :category, :subcategories

    delegate :name, :color, to: :category

    def self.for(categories)
      categories.select { |category| category.parent_id.nil? }.map do |category|
        new(category, category.subcategories)
      end
    end

    def initialize(category, subcategories = nil)
      @category = category
      @subcategories = subcategories || []
    end
  end

  class << self
    def suggested_icon(name)
      name_down = name.to_s.downcase

      ICON_KEYWORDS.each do |pattern, icon|
        return icon if name_down.match?(pattern)
      end

      "shapes"
    end

    def icon_codes
      %w[
        ambulance apple award baby badge-dollar-sign banknote barcode bar-chart-3 bath
        battery bed-single beer bike bluetooth bone book book-open briefcase building bus
        cake calculator calendar-heart calendar-range camera car cat chart-line
        circle-dollar-sign circle-parking coffee coins compass cookie cooking-pot
        credit-card dices dog drama drill droplet drum dumbbell film flame flower flower-2
        fuel gamepad-2 gem gift glasses globe graduation-cap hammer hand-heart
        hand-helping heart-handshake handshake headphones heart heart-pulse home hotel
        house ice-cream-cone key landmark laptop leaf lightbulb luggage mail map-pin
        martini mic monitor moon music package palette party-popper paw-print pen pencil
        percent phone pie-chart piggy-bank pill pizza plane plug popcorn power printer
        puzzle receipt receipt-text ribbon scale scissors settings shield shield-plus
        shirt shopping-bag shopping-basket shopping-cart smartphone sparkles sprout
        stethoscope store sun tablet-smartphone tag target tent thermometer ticket train
        trees tree-palm trending-up trophy truck tv umbrella undo-2 unplug users utensils
        video wallet wallet-cards waves wifi wine wrench zap
      ]
    end

    def bootstrap!
      default_categories.each do |name, color, icon|
        find_or_create_by!(name: name) do |category|
          category.color = color
          category.lucide_icon = icon
        end
      end
    end

    def uncategorized
      new(
        name: I18n.t(UNCATEGORIZED_NAME_KEY),
        color: UNCATEGORIZED_COLOR,
        lucide_icon: "circle-dashed"
      )
    end

    def other_investments
      new(
        name: I18n.t(OTHER_INVESTMENTS_NAME_KEY),
        color: OTHER_INVESTMENTS_COLOR,
        lucide_icon: "trending-up"
      )
    end

    # Helper to get the localized name for uncategorized
    def uncategorized_name
      I18n.t(UNCATEGORIZED_NAME_KEY)
    end

    # Returns all possible uncategorized names across all supported locales
    # Used to detect uncategorized filter regardless of URL parameter language
    def all_uncategorized_names
      LanguagesHelper::SUPPORTED_LOCALES.map do |locale|
        I18n.t(UNCATEGORIZED_NAME_KEY, locale: locale)
      end.uniq
    end

    # Helper to get the localized name for other investments
    def other_investments_name
      I18n.t(OTHER_INVESTMENTS_NAME_KEY)
    end

    # Helper to get the localized name for investment contributions
    def investment_contributions_name
      I18n.t(INVESTMENT_CONTRIBUTIONS_NAME_KEY)
    end

    # Returns all possible investment contributions names across all supported locales
    # Used to detect investment contributions category regardless of locale
    def all_investment_contributions_names
      LanguagesHelper::SUPPORTED_LOCALES.map do |locale|
        I18n.t(INVESTMENT_CONTRIBUTIONS_NAME_KEY, locale: locale)
      end.uniq
    end

    private
      def default_categories
        [
          [ I18n.t("models.category.defaults.income"),               "#22c55e", "circle-dollar-sign" ],
          [ I18n.t("models.category.defaults.reimbursement"),        "#16a34a", "circle-dollar-sign" ],
          [ I18n.t("models.category.defaults.groceries"),            "#407706", "shopping-bag" ],
          [ I18n.t("models.category.defaults.restaurants"),          "#f97316", "utensils" ],
          [ I18n.t("models.category.defaults.shopping"),             "#3b82f6", "shopping-cart" ],
          [ I18n.t("models.category.defaults.transportation"),       "#0ea5e9", "bus" ],
          [ I18n.t("models.category.defaults.gas"),                  "#64748b", "fuel" ],
          [ I18n.t("models.category.defaults.mechanic"),             "#475569", "car" ],
          [ I18n.t("models.category.defaults.subscriptions"),        "#6366f1", "wifi" ],
          [ I18n.t("models.category.defaults.electricity"),          "#eab308", "zap" ],
          [ I18n.t("models.category.defaults.home_improvement"),     "#d97706", "hammer" ],
          [ I18n.t("models.category.defaults.car_loan"),             "#e11d48", "credit-card" ],
          [ I18n.t("models.category.defaults.windows_loan"),         "#be185d", "credit-card" ],
          [ I18n.t("models.category.defaults.air_conditionner_load"), "#9333ea", "credit-card" ],
          [ I18n.t("models.category.defaults.house_loan"),           "#dc2626", "credit-card" ],
          [ I18n.t("models.category.defaults.pharmacy"),             "#4da568", "pill" ],
          [ I18n.t("models.category.defaults.daycare"),              "#a855f7", "baby" ],
          [ I18n.t("models.category.defaults.vet"),                  "#10b981", "paw-print" ],
          [ I18n.t("models.category.defaults.dog_food"),             "#84cc16", "paw-print" ],
          [ I18n.t("models.category.defaults.investment"),           "#059669", "trending-up" ],
          [ I18n.t("models.category.defaults.kid_investmenet"),      "#0d9488", "trending-up" ],
        ]
      end
  end

  def inherit_color_from_parent
    if subcategory?
      self.color = parent.color
    end
  end

  def replace_and_destroy!(replacement)
    transaction do
      transactions.update_all category_id: replacement&.id
      destroy!
    end
  end

  def parent?
    subcategories.any?
  end

  def subcategory?
    parent.present?
  end

  def name_with_parent
    subcategory? ? "#{parent.name} > #{name}" : name
  end

  # Predicate: is this the synthetic "Uncategorized" category?
  def uncategorized?
    !persisted? && name == I18n.t(UNCATEGORIZED_NAME_KEY)
  end

  # Predicate: is this the synthetic "Other Investments" category?
  def other_investments?
    !persisted? && name == I18n.t(OTHER_INVESTMENTS_NAME_KEY)
  end

  # Predicate: is this any synthetic (non-persisted) category?
  def synthetic?
    uncategorized? || other_investments?
  end

  private
    def category_level_limit
      if (subcategory? && parent.subcategory?) || (parent? && subcategory?)
        errors.add(:parent, "can't have more than 2 levels of subcategories")
      end
    end

    def monetizable_currency
      family.currency
    end
end
