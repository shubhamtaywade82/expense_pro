# frozen_string_literal: true

module Ai
  module Tools
    class DebtHandler
      def initialize(user)
        @user = user
      end

      def debt_overview
        overview = DebtClearanceService.new(@user).overview
        {
          success: true,
          totals: overview[:totals],
          settlement_fund: overview[:settlement_fund],
          estimated_debt_free_on: overview[:estimated_debt_free_on],
          next_settlement: overview[:next_settlement],
          cashflow: overview[:cashflow]
        }
      end

      def settlement_queue
        entries = DebtQueueRanker.new(@user).call
        {
          success: true,
          queue: entries.map do |e|
            {
              settlement_case_id: e.settlement_case.id,
              name: e.debt_account.name,
              lender: e.debt_account.lender,
              claim: e.debt_account.current_balance.to_f,
              stage: e.stage,
              score: e.score,
              estimated_total: e.estimated_total_paise / 100.0,
              funding_progress: e.funding_progress,
              eligible: e.eligible,
              status: e.settlement_case.status
            }
          end
        }
      end

      def settle_with_amount(args)
        amount = args["amount"].to_f
        return { success: false, message: "amount is required" } if amount <= 0

        result = SettlementSimulator.new(@user).call(available_cash: amount)
        { success: true, simulation: result }
      end

      def debt_forecast(args)
        result = DebtForecastEngine.new(@user, monthly_allocation: args["monthly_allocation"]).call
        {
          success: true,
          monthly_allocation: result.monthly_allocation,
          settlements: result.settlements,
          debt_free_on: result.debt_free_on,
          total_settlement_cost: result.total_settlement_cost,
          note: ("Could not settle everything within #{DebtForecastEngine::MAX_MONTHS} months" if result.settlements.size < DebtQueueRanker.new(@user).call.size)
        }
      end

      def compare_settlement_scenarios(args)
        settlement_case = find_settlement_case(args)
        return { success: false, message: "Settlement case not found" } if settlement_case.nil?

        {
          success: true,
          settlement_case_id: settlement_case.id,
          account: settlement_case.debt_account.name,
          claim: settlement_case.current_claim.to_f,
          scenarios: DebtClearanceService.new(@user).scenario_table(settlement_case)
        }
      end

      def add_settlement_contribution(args)
        settlement_case = find_settlement_case(args)
        return { success: false, message: "Settlement case not found" } if settlement_case.nil?

        contribution = settlement_case.settlement_contributions.create!(
          user: @user,
          amount: args["amount"].to_d,
          contributed_on: Date.parse(args["contributed_on"] || Date.current.to_s),
          source: args["source"] || "salary",
          notes: args["notes"]
        )
        settlement_case.update!(status: :funding) if settlement_case.drafting?

        {
          success: true,
          message: "Contribution saved",
          contribution: { id: contribution.id, amount: contribution.amount.to_s },
          settlement_fund: settlement_case.settlement_fund_paise / 100.0,
          funding_progress: settlement_case.funding_progress
        }
      end

      def list_credit_cards(_args)
        cards = @user.debt_accounts.where(debt_type: :credit_card).map do |card|
          limit = card.credit_limit.to_f
          balance = card.current_balance.to_f
          overdue = card.overdue_amount.to_f
          {
            id: card.id,
            name: card.name,
            lender: card.lender,
            account_number_masked: card.account_number_masked,
            credit_limit: limit,
            current_balance: balance,
            overdue_amount: overdue,
            utilization_percentage: card.utilization_percentage,
            over_limit: card.over_limit?,
            due_day: card.due_day,
            statement_day: card.statement_day,
            bureau_status: card.bureau_status || "CURRENT"
          }
        end
        { success: true, count: cards.size, credit_cards: cards }
      end

      def list_debt_accounts(args)
        scope = @user.debt_accounts
        scope = scope.where(debt_type: args["debt_type"]) if args["debt_type"].present?
        scope = scope.where(classification: args["classification"]) if args["classification"].present?
        scope = scope.where("overdue_amount_paise > 0") if args["overdue_only"]

        accounts = scope.map do |acc|
          {
            id: acc.id,
            name: acc.name,
            lender: acc.lender,
            debt_type: acc.debt_type,
            classification: acc.classification,
            current_balance: acc.current_balance.to_f,
            overdue_amount: acc.overdue_amount.to_f,
            monthly_obligation: acc.monthly_obligation.to_f,
            interest_rate: acc.interest_rate.to_f,
            bureau_status: acc.bureau_status || "CURRENT",
            account_number_masked: acc.account_number_masked
          }
        end
        { success: true, count: accounts.size, accounts: accounts }
      end

      def get_legal_status(_args)
        legal_cases = @user.debt_accounts.where("bureau_status ILIKE ? OR name ILIKE ?", "%SUIT%", "%akara%").map do |acc|
          {
            account_id: acc.id,
            name: acc.name,
            lender: acc.lender,
            claim_amount: acc.current_balance.to_f,
            overdue_amount: acc.overdue_amount.to_f,
            bureau_status: acc.bureau_status,
            urgency: "CRITICAL - ACTION REQUIRED",
            recommended_strategy: "Initiate formal One-Time Settlement (OTS) letter targeting 25-35% of principal."
          }
        end
        {
          success: true,
          alert_count: legal_cases.size,
          has_critical_legal_alerts: legal_cases.any?,
          alerts: legal_cases
        }
      end

      def generate_ots_letter(args)
        account = find_debt_account(args)
        return { success: false, message: "Account not found" } if account.nil?

        target_pct = (args["proposed_percentage"] || 25).to_f
        claim = account.current_balance.to_f
        ots_offer = (claim * (target_pct / 100.0)).round(2)

        letter = <<~LETTER
          WITHOUT PREJUDICE / SUBJECT TO MUTUAL AGREEMENT

          To,
          The Authorized Officer / Legal Cell,
          #{account.lender}

          Subject: Proposal for Full and Final One-Time Settlement (OTS)
          Account Name: #{account.name}
          Account Number: #{account.account_number_masked}
          Total Claimed Amount: ₹#{claim.round(2)}

          Dear Sir/Madam,

          I, #{@user.name}, hold the aforementioned account with your esteemed institution. Due to severe and unforeseen financial distress, I have been unable to service the outstanding dues.

          In accordance with RBI prudential guidelines on Resolution of Stressed Assets, I formally propose a One-Time Settlement (OTS) of ₹#{ots_offer.round(2)} (approx. #{target_pct.to_i}% of the claim) as full and final payment.

          Terms of Settlement:
          1. Payment of ₹#{ots_offer.round(2)} upon receipt of a formal OTS sanction letter on bank letterhead.
          2. Issuance of a formal No Dues Certificate (NDC).
          3. Updating credit bureaus (CIBIL/CRIF High Mark/Equifax) as "Settled / Closed".
          4. Withdrawal of all legal / arbitration notices or proceedings without cost.

          Kindly confirm acceptance within 15 days.

          Yours sincerely,
          #{@user.name}
          Email: #{@user.email}
        LETTER

        {
          success: true,
          account_id: account.id,
          account_name: account.name,
          lender: account.lender,
          claim_amount: claim,
          proposed_settlement_amount: ots_offer,
          letter_text: letter
        }
      end

      private

      def find_settlement_case(args)
        if args["settlement_case_id"].present?
          @user.settlement_cases.find_by(id: args["settlement_case_id"])
        else
          scope = @user.settlement_cases.open.joins(:debt_account)
          scope.where("debt_accounts.name ILIKE ?", "%#{args["account_name"]}%").first ||
            scope.where("debt_accounts.lender ILIKE ?", "%#{args["account_name"]}%").first
        end
      end

      def find_debt_account(args)
        if args["debt_account_id"].present?
          @user.debt_accounts.find_by(id: args["debt_account_id"])
        else
          @user.debt_accounts.where("name ILIKE ? OR lender ILIKE ?", "%#{args["lender"] || args["account_name"]}%", "%#{args["lender"] || args["account_name"]}%").first
        end
      end
    end
  end
end
