# Budgets — design (agreed 2026-10-06)

## Goal
Help the user control spending, not just record it: a monthly limit, how much is left, and a
notification before (and when) it runs out.

## What the user sets
- **Monthly budget** (overall), e.g. ₹25,000. Optional.
- **Category budgets**, only for the categories the user wants to watch. Optional.
- **Alerts: one shared setting** for every budget: on by default; warn at two percentages
  (default 80% and 90%; each 50–95%, the second higher than the first) and when a budget is over.

## Rules
- Only expenses count. Income (including refunds) never lowers spending.
- Overall = every expense in the calendar month; a category budget = that category's expenses.
  Split parts count in their own category (they are ordinary expense rows).
- Payments still waiting for a label don't count; Home shows them separately.
- A budget repeats every month until changed. A new amount applies from the current month on;
  past months keep the amount they had. Removing a budget stops it from the current month on.
  Unspent money does not roll over.
- A category's budget follows a rename and is removed when the category is deleted.
- Status: spent vs. an even pace (limit × day ÷ days in month) → on track / ahead of pace
  ("at this pace ~₹X over by <last day>") / over by ₹X.

## Alerts
- Checked after every change, in the app and in the background (notification and widget buttons).
- Levels: 1 = first warning, 2 = second warning, 3 = over (spent > limit).
- A level fires once per budget per month. The level reached is stored each check, so dropping
  below a level (an entry deleted, the budget raised) lets it fire again when crossed again.
- One payment that crosses several levels sends one notification, for the highest level.
- Own notification channel "Budget alerts"; tapping one opens Insights.

## Where it shows
- Settings → Budgets: monthly budget, category budgets (+ Add a category budget), alert settings.
- Home: a budget card under the balance ("₹17,707 left of ₹25,000", a bar with today's even-pace
  mark, "29% used · 26 days left · on track", "+ ₹1,250 waiting to be labelled"). With no budget
  at all, a dismissible "Set a monthly budget" card instead.
- Insights: the month's budget card, and "₹4,200 of ₹6,000" with a bar on budgeted category rows.
- Widgets: "This month so far" adds "₹17,707 left of ₹25,000"; "Where it went" shows
  "₹4,200 / ₹6K" on budgeted rows.

## Data
- Schema v11: table `budgets(id, category TEXT NOT NULL — '' = overall, amount REAL — NULL =
  removed, from_month TEXT 'YYYY-MM', UNIQUE(category, from_month))`, in backups.
- Alert settings and the per-month level reached live in `settings`
  (`budget_alerts`, `budget_warn_1`, `budget_warn_2`, `budget_level:<category>:<YYYY-MM>`).
- Older backups restore with no budgets.

## Out of scope
"Spending more than last month" alerts (dropped), rollover, refunds as negative spending,
weekly/yearly budgets, SMS catch-up.
