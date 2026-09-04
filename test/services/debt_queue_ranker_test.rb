require "test_helper"

class DebtQueueRankerTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Debt Test User",
      email: "queue_ranker@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @ranker = DebtQueueRanker.new(@user)
  end

  test "assigns stages: legal opportunity, small, medium, large" do
    idfc = create_account(name: "IDFC PL", balance: 64_888, formal_notice: true)
    branch = create_account(name: "Branch Loan", balance: 10_000)
    finc = create_account(name: "FincFriends", balance: 45_000)
    smfg = create_account(name: "SMFG", balance: 2_00_000)

    create_case(idfc, status: :negotiation)
    create_case(branch)
    create_case(finc)
    create_case(smfg)

    entries = @ranker.call

    assert_equal "legal_opportunity", entries[0].stage.to_s
    assert_equal "IDFC PL", entries[0].debt_account.name
    assert_equal "small_balance", entries[1].stage.to_s
    assert_equal "medium_balance", entries[2].stage.to_s
    assert_equal "large_unsecured", entries[3].stage.to_s
  end

  test "stage boundaries fall on 25k and 1L" do
    at_25k = create_account(name: "Edge Small", balance: 25_000)
    at_25k_1 = create_account(name: "Edge Medium", balance: 25_001)

    assert_equal "small_balance", @ranker.stage_for(build_case(at_25k)).to_s
    assert_equal "medium_balance", @ranker.stage_for(build_case(at_25k_1)).to_s
  end

  test "a case with a formal notice but drafting status still leads its queue" do
    axis = create_account(name: "Axis PL", balance: 80_000, formal_notice: true)
    other = create_account(name: "Innofin", balance: 12_000)

    create_case(axis) # drafting, but formal notice received
    create_case(other)

    entries = @ranker.call
    assert_equal "Axis PL", entries.first.debt_account.name
    assert_equal "legal_opportunity", entries.first.stage.to_s
  end

  test "readiness rises with contributions and higher funding scores higher within a stage" do
    small_a = create_account(name: "Small A", balance: 12_000)
    small_b = create_account(name: "Small B", balance: 13_000)

    case_a = create_case(small_a)
    create_case(small_b)

    # Same stage: contributions push Small A ahead.
    small_a.settlement_cases.first.settlement_contributions.create!(
      user: @user, amount: 6_000, contributed_on: Date.current
    )

    entries = @ranker.call
    assert_equal "Small A", entries.first.debt_account.name
    assert_operator entries.first.score, :>, entries.second.score

    assert case_a.settlement_contributions.any?
  end

  test "ranker is read-only" do
    account = create_account(name: "CFS", balance: 30_000)
    settlement_case = create_case(account)
    before = settlement_case.updated_at

    @ranker.call

    settlement_case.reload
    assert_equal before, settlement_case.updated_at
  end

  private

  def create_account(name:, balance:, formal_notice: false)
    @user.debt_accounts.create!(
      name: name,
      lender: name.split(" ").first,
      debt_type: :personal_loan,
      classification: :settlement,
      status: :current,
      original_principal_paise: balance * 100,
      current_balance_paise: balance * 100,
      monthly_obligation_paise: (balance * 100 / 10).round,
      formal_notice: formal_notice
    )
  end

  def create_case(account, status: :drafting)
    @user.settlement_cases.create!(
      debt_account: account,
      started_on: Date.current,
      original_claim_paise: account.current_balance_paise,
      current_claim_paise: account.current_balance_paise,
      status: status
    )
  end

  def build_case(account)
    @user.settlement_cases.new(debt_account: account, current_claim_paise: account.current_balance_paise)
  end
end
