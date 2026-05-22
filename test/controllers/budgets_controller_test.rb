require "test_helper"

class BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
  end

  # ===========================================================================
  # update_period
  # ===========================================================================

  test "update_period changes family month_start_day" do
    assert_equal 1, @family.month_start_day

    patch update_period_budgets_path, params: { month_start_day: 15 }

    assert_equal 15, @family.reload.month_start_day
  end

  test "update_period redirects to the edit page of the new current period budget" do
    travel_to Date.new(2026, 5, 26) do
      patch update_period_budgets_path, params: { month_start_day: 25 }

      # After setting start day to 25, today (May 26) is inside the May 25 – Jun 24 period
      new_budget = Budget.find_by(family: @family, start_date: Date.new(2026, 5, 25))
      assert_not_nil new_budget
      assert_redirected_to edit_budget_path(new_budget)
    end
  end

  test "update_period clamps out-of-range values" do
    patch update_period_budgets_path, params: { month_start_day: 99 }
    assert_equal 28, @family.reload.month_start_day

    patch update_period_budgets_path, params: { month_start_day: 0 }
    assert_equal 1, @family.reload.month_start_day
  end

  test "update_period to day 1 keeps standard calendar-month budget" do
    @family.update!(month_start_day: 15)

    travel_to Date.new(2026, 5, 10) do
      patch update_period_budgets_path, params: { month_start_day: 1 }

      new_budget = Budget.find_by(family: @family, start_date: Date.new(2026, 5, 1))
      assert_not_nil new_budget
      assert_redirected_to edit_budget_path(new_budget)
    end
  end
end
